import AppSettings_Api
import AppSettings_Impl
import ConcurrencyApi
import Core_Common_Api
import UIKit

protocol MainNavigationRouting: DeeplinkRouting {
    func moveToViewingMode(_ mode: ViewingModeType, tab: TabProtocol?, animated: Bool, completion: (() -> Void)?)
    func moveToViewingMode(_ mode: ViewingModeType, animated: Bool, completion: (() -> Void)?)
    func resetToInitialTabIfNeeded(scrollToTop: Bool)
    func scrollInitialTabToTopIfNeeded(animated: Bool)
    func openProfiles()
    func editProfile()
    func getCurrentTabViewController() -> UIViewController?
    func showTransparencyPopupsIfNeeded()
}

class MainNavigationRouter: DeeplinkRouting, MainNavigationRouting {
    private weak var navigationContainer: (MainNavigationContainer & MainTabSwitcher)?
    private weak var selectedViewController: UIViewController?
    private let openProfilesAction: (() -> Void)?
    private let editProfileAction: (() -> Void)?
    private let trackingTransparency: TrackingTransparency
    private let features: Features
    private let taskRunner: ConcurrencyTaskRunner

    var childDeeplinkRouters: DeeplinkRoutersList = DeeplinkRoutersList()
    var showTransparencyPopupsCallBack: (() -> Void)?

    init(
        _ navigationController: (MainNavigationContainer & MainTabSwitcher)?,
        openProfilesAction: (() -> Void)?,
        editProfileAction: (() -> Void)?,
        features: Features = Dependency.resolve(Features.self),
        trackingTransparency: TrackingTransparency,
        taskRunner: ConcurrencyTaskRunner
    ) {
        self.navigationContainer = navigationController
        self.openProfilesAction = openProfilesAction
        self.editProfileAction = editProfileAction
        self.features = features
        self.trackingTransparency = trackingTransparency
        self.taskRunner = taskRunner
    }

    func moveToViewingMode(_ mode: ViewingModeType, animated: Bool, completion: (() -> Void)?) {
        moveToViewingMode(mode, tab: nil, animated: animated, completion: completion)
    }

    func moveToViewingMode(_ mode: ViewingModeType, tab: TabProtocol? = nil, animated: Bool, completion: (() -> Void)?) {
        guard let container = navigationContainer else { return }

        switch mode {
        case .myAccount:
            showMyAccount(on: container, tab: tab)
        default:
            showViewController(mode: mode, animated: animated, container: container, completion: completion)
        }
    }

    func resetToInitialTabIfNeeded(scrollToTop: Bool = false) {
        if let navigationController = selectedViewController as? UINavigationController,
           let browse = navigationController.topViewController as? LegacyBrowseViewController {
            browse.resetToInitialTabIfPossible(scrollToTop: scrollToTop)
        }
    }

    func scrollInitialTabToTopIfNeeded(animated: Bool = false) {
        if let navigationController = selectedViewController as? UINavigationController,
           let browse = navigationController.topViewController as? LegacyBrowseViewController {
            browse.scrollInitialTabToTop(animated: animated)
        }
    }

    func openProfiles() {
        openProfilesAction?()
    }

    func editProfile() {
        editProfileAction?()
    }

    func getCurrentTabViewController() -> UIViewController? {
        return selectedViewController
    }

    private func showMyAccount(
        on container: MainNavigationContainer,
        tab: TabProtocol? = nil
    ) {
        let coordinator = MyAccountCoordinator(
            hostController: container,
            myAccountFactory: Dependency.resolve(MyAccountFactory.self),
            trackingTransparency: trackingTransparency
        )
        coordinator.start(withTab: tab)
    }

    private func showViewController(mode: ViewingModeType, animated: Bool, container: MainNavigationContainer, completion: (() -> Void)?) {
        guard let destination = container.viewControllers[mode], destination != selectedViewController else {
            completion?()
            return
        }
        DeeplinkNotificationHandler.dismissActiveNotificationIfNeeded()
        EmailVerificationNotificationHandler.dismissActiveNotificationIfNeeded()
        changeSelectedViewControllerTo(destination, mode: mode, animated: animated, container: container, completion: completion)
    }

    private func changeSelectedViewControllerTo(_ destination: UIViewController, mode: ViewingModeType, animated: Bool, container: MainNavigationContainer, completion: (() -> Void)?) {
        // FIXME: ⚠️ Removed defer and added line 64, 70 to solve the issue on ticket https://gspcloud.atlassian.net/browse/MOB-2098
        guard let source = selectedViewController else {
            MainNavigationTransition.replace.set(destination, parent: container)
            selectedViewController = destination
            completion?()
            return
        }
        let transition = transitionAnimatingTo(mode, container: container)
        transition.run(dismissed: source, presented: destination, parent: container, animated: animated, completion: completion)
        selectedViewController = destination
    }

    private func transitionAnimatingTo(_ mode: ViewingModeType, container: MainNavigationContainer) -> MainNavigationTransition {
        if selectedViewController == container.viewControllers[.downloads] {
            return .animateRight
        }

        if selectedViewController == container.viewControllers[.search] {
            return .animateLeft
        }

        switch mode {
        case .channels:
            return selectedViewController == container.viewControllers[.browse] ? .animateRight : .animateLeft
        case .downloads:
            return .animateLeft
        case .browse:
            return selectedViewController == container.viewControllers[.channels] ? .animateLeft : .animateRight
        default:
            return .animateRight
        }
    }

    @objc
    private func dismiss(_ sender: UIBarButtonItem) {
        navigationContainer?.dismiss(animated: true, completion: nil)
    }

    func handle(deeplink: Deeplink) {
        let completionBlock: () -> Void = { [weak self] in
            guard let self = self else { return }

            let defaultBrowseAction = { [weak self] in
                self?.navigationContainer?.setSelectedMode(.browse, result: deeplink, animated: false) {
                    self?.notifyChildren(deeplink: deeplink)
                }
            }

            let homeNavigationAction = { [weak self] in
                self?.navigationContainer?.setSelectedMode(.browse, result: deeplink, animated: false, completion: nil)
            }

            switch deeplink.action {
            case .playback(let type), .pdpAutoPlay(let type):
                switch type {
                case .channel:
                    guard self.features.isEnabled(.isChannelsEnabled) else {
                        homeNavigationAction()
                        return
                    }

                    self.navigationContainer?.setSelectedMode(.channels, result: deeplink, animated: false) { [weak self] in
                        self?.notifyChildren(deeplink: deeplink)
                    }
                default:
                    defaultBrowseAction()
                }
            case .pdp, .pdpAddToMyStuff, .voiceAI:
                defaultBrowseAction()
            case .home(let error):
                homeNavigationAction()
                if error != nil {
                    DeeplinkNotificationHandler.show(.assetNotAvailable)
                }
            case .open(_), .roadblock, .myAccount, .planPicker, .filteredPlanPicker:
                break
            }
        }

        if let presentedVc = navigationContainer?.navigationController?.presentedViewController {
            presentedVc.dismiss(animated: false, completion: completionBlock)
        } else {
            completionBlock()
        }
    }

    func showTransparencyPopupsIfNeeded() {
        showTransparencyPopupsCallBack?()
    }
}
