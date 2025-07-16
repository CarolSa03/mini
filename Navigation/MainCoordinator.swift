import Account_Api
import Analytics
import AppReportingApi
import AppSettings_Api
import Collections_Api
import Combine
import CombineSchedulers
import MainHeaderUi
import PersonasApi
import UIKit

class MainCoordinator: MainCoordinatorProtocol, CoordinatorDelegate {
    // MARK: Properties

    private enum ErrorConstants {
        static let contentNotAvailableForKids: String = "Content not available for kids"
        static let deeplinkNotAvailableForFailover: String = "Deeplink to add to MyStuff not avaiable due to profile failover"
        static let sectionNotAvailable: String = "Section not available"
    }

    private lazy var mainTabBarHeightFromBottom: CGFloat? = {
        mainViewController?.getMainTabBarHeightFromBottom()
    }()
    private let hostViewController: AppContainerViewControllerProtocol
    private let appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating
    private let hasNoAccessAccountSegmentUseCase: any HasNoAccessAccountSegmentUseCase
    private let observePersonasUseCase: any ObservePersonasUseCase
    private let persona: Persona
    private let factory: MainCoordinatorFactoryProtocol
    private let analytics: AnalyticsProtocol
    private let features: Features
    private let trackingTransparency: TrackingTransparency
    private let reporter: ReportManager
    private var handleSubscribedPlanResultCompletionBlock: (() -> Void)?
    private let mainScheduler: AnySchedulerOf<DispatchQueue>

    private weak var mainViewController: MainTabBarViewController?
    private var personasSubscription: AnyCancellable?

    var childDeeplinkRouters: DeeplinkRoutersList = DeeplinkRoutersList()
    var childCoordinators: [Coordinator] = []
    weak var delegate: CoordinatorDelegate?

    // MARK: Initializer

    init(
        hostViewController: AppContainerViewControllerProtocol,
        appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating,
        hasNoAccessAccountSegmentUseCase: any HasNoAccessAccountSegmentUseCase,
        observePersonasUseCase: any ObservePersonasUseCase,
        persona: Persona,
        factory: MainCoordinatorFactoryProtocol,
        analytics: AnalyticsProtocol,
        features: Features,
        trackingTransparency: TrackingTransparency,
        reporter: ReportManager,
        handleSubscribedPlanResultCompletionBlock: (() -> Void)?,
        mainScheduler: AnySchedulerOf<DispatchQueue>
    ) {
        self.hostViewController = hostViewController
        self.appContainerAnimationCoordinator = appContainerAnimationCoordinator
        self.hasNoAccessAccountSegmentUseCase = hasNoAccessAccountSegmentUseCase
        self.observePersonasUseCase = observePersonasUseCase
        self.persona = persona
        self.analytics = analytics
        self.features = features
        self.factory = factory
        self.trackingTransparency = trackingTransparency
        self.reporter = reporter
        self.handleSubscribedPlanResultCompletionBlock = handleSubscribedPlanResultCompletionBlock
        self.mainScheduler = mainScheduler
    }
}

// MARK: - Coordinator

extension MainCoordinator {
    func start() {
        self.start(animated: true, completion: nil)
    }

    func start(with deeplink: Deeplink, animated: Bool) {
        self.start(animated: true) { [weak self] in
            self?.handle(deeplink: deeplink)
        }
    }

    func coordinatorDidFinish(_ coordinator: Coordinator, result: Any?) {
        if let result = result as? PlanPickerCoordinator.Result, case .didGoBack(let shouldShowRoadblock) = result {
            if shouldShowRoadblock {
                let goToRoadblockResult = MainCoordinator.Result(persona: persona, action: .roadblock)
                delegate?.coordinatorDidFinish(self, result: goToRoadblockResult)
            }
        }

        if coordinator is MyAccountCoordinator || coordinator is PlanPickerCoordinator {
            return
        }

        finishCoordinatorExecution(result: result)
    }
}

// MARK: - DeeplinkRouting

extension MainCoordinator {
    func handle(deeplink: Deeplink) {
        if case .myAccount = deeplink.action {
            return goToMyAccount(with: deeplink)
        }

        if case .planPicker = deeplink.action {
            return selectModeHandler(deeplink: deeplink)
        }

        if deeplink.action.isRoadblock {
            finishCoordinatorExecution(result: deeplink)
            return
        }

        guard persona.type != .kid || deeplink.isSuitableForKids() else {
            reporter.reportError(
                domain: AppErrorDomain.deeplink(),
                message: ErrorConstants.contentNotAvailableForKids,
                severity: .error,
                dependency: .deeplink
            )
            self.finishCoordinatorExecution(result: deeplink)
            return
        }

        guard !hasNoAccessAccountSegmentUseCase.execute() else { return }

        selectModeHandler(deeplink: deeplink)
    }

    func presentLoading() {
        mainViewController?.dismiss(animated: true)
        guard let viewController = mainViewController else { return }
        let configuration = LoadingSpinnerViewConfiguration(
            backgroundColor: Theme.Seamless.backgroundColor,
            overridingPresentationDelay: 0
        )
        LoadingSpinnerView.presentLoadingSpinner(
            on: viewController.view,
            configuration: configuration
        )
    }

    func dismissLoading() {
        guard let viewController = mainViewController else { return }
        LoadingSpinnerView.dismissLoadingSpinner(on: viewController.view)
    }

    private func goToMyAccount(with deeplink: Deeplink) {
        let coordinator = factory.makeMyAccountCoordinator(hostViewController: hostViewController)
        addChildCoordinator(coordinator)
        coordinator.start(with: deeplink, animated: true)
    }
}

// MARK: - MainProfilesNavigationDelegate

extension MainCoordinator: MainProfilesNavigationDelegate {
    func goToProfilesScene(button: UIView?, result: Any? = nil) {
        self.appContainerAnimationCoordinator.profileButtonContainer = button
        self.finishCoordinatorExecution(result: result)
    }
}

// MARK: - MainTabLoading

extension MainCoordinator: MainTabLoading {
    func loadTabContent(for tabs: [MainTabBarMenuItem]) {
        guard let hostViewController = self.mainViewController else {
            assertionFailure("Invalid state - cannot create coordinators for main tab items without a host view controller")
            return
        }

        for case .item(type: let type, name: _, icon: _) in tabs {
            let coordinator = self.createCoordinatorFor(
                type: type,
                with: hostViewController,
                mainNavigationHandler: hostViewController
            )

            self.addChildCoordinator(coordinator)
            coordinator.start()
        }
    }
}

// MARK: - MainHeaderDelegate

extension MainCoordinator: MainHeaderDelegate {
    func didTapLogo() {
        guard self.persona.type != .kid else { return }

        self.resetToInitialTabIfNeeded(scrollToTop: true)
        self.scrollInitialTabToTopIfNeeded(animated: true)
        self.analytics.track(event: .navigation(.peacockLogoTapped))
    }
}

// MARK: - Private (coordinator life cycle)

private extension MainCoordinator {
    func start(animated: Bool, completion: (() -> Void)?) {
        let viewController = self.factory.makeMainTabBarViewController()
        viewController.mainTabLoading = self
        viewController.mainProfilesNavigationDelegate = self
        viewController.header.delegate = self
        self.mainViewController = viewController

        let playerAnalyticsProvider = PlayerAnalyticsProvider(analytics: analytics)
        PlayerAnalyticsProvider.setInstance(playerAnalyticsProvider)

        let miniRemoteContainerController = MainContainerViewController(with: viewController)
        hostViewController.showContentViewController(miniRemoteContainerController, animated: animated, completion: { [weak self] in
            self?.handleSubscribedPlanResultCompletionBlock?()
            self?.handleSubscribedPlanResultCompletionBlock = nil
            self?.startObservingPersonas()
            completion?()
        })
    }

    func showTransparencyPopupsIdNeeded() {
        self.trackingTransparency.showPopupsIfNeeded(attachingTo: hostViewController)
    }

    func finishCoordinatorExecution(result: Any? = nil) {
        personasSubscription?.cancel()
        delegate?.coordinatorDidFinish(self, result: result)
    }

    func createCoordinatorFor(type: MainMenuItemType, with hostViewController: MainNavigationUpdatable & ChannelGuideDataPassing, mainNavigationHandler handler: MainNavigationHandler) -> Coordinator {
        switch type {
        case .home:
            let coordinator = self.factory.makeBrowseCoordinator(
                hostViewController: hostViewController,
                mainNavigationHandler: handler,
                mainTabBarHeightFromBottom: mainTabBarHeightFromBottom
            )

            PlayerNavigationHandler.setInstance(
                self.factory.makePlayerNavigationHandler(
                    mainNavigationHandler: handler,
                    mainNavigationDelegate: coordinator as? MainNavigationDelegate
                )
            )

            return coordinator

        case .channels:
            return self.factory.makeChannelGuideCoordinator(hostViewController: hostViewController, mainNavigationHandler: handler)

        case .downloads:
            return self.factory.makeDownloadsCoordinator(hostViewController: hostViewController)

        case .search:
            return self.factory.makeSearchCoordinator(hostViewController: hostViewController, mainNavigationHandler: handler)
        }
    }

    private func startObservingPersonas() {
        personasSubscription = observePersonasUseCase.execute()
            .compactMap { $0 }
            .receive(on: mainScheduler)
            .sink(receiveValue: { [weak self] personas in
                guard let strongSelf = self, !personas.contains(where: { $0.id == strongSelf.persona.id }) else {
                    return
                }
                strongSelf.finishCoordinatorExecution()
            })
    }
}

// MARK: - Private (tabbing)

private extension MainCoordinator {
    func resetToInitialTabIfNeeded(scrollToTop scroll: Bool = false) {
        self.onBrowseIfSelected { $0.resetToInitialTabIfPossible(scrollToTop: scroll) }
    }

    func scrollInitialTabToTopIfNeeded(animated: Bool = false) {
        self.onBrowseIfSelected { $0.scrollInitialTabToTop(animated: animated) }
    }

    private func onBrowseIfSelected(perform action: (LegacyBrowseViewController) -> Void) {
        if let navigationController = self.mainViewController?.selectedViewController as? UINavigationController,
           let browse = navigationController.topViewController as? LegacyBrowseViewController {
            action(browse)
        }
    }

    private func selectModeHandler(deeplink: Deeplink) {
        switch deeplink.action {
        case .pdpAddToMyStuff where persona.isFailover:
            reporter.reportError(
                domain: AppErrorDomain.deeplink(),
                message: ErrorConstants.deeplinkNotAvailableForFailover,
                severity: .error,
                dependency: .clip
            )
            finishCoordinatorExecution(result: deeplink)
            return
        case .playback(.channel), .pdpAutoPlay(.channel):
            mainViewController?.setSelectedMode(.channels, animated: false)
        case .open(let sectionId):
            openSelectMode(sectionId)
        case .myAccount:
            mainViewController?.setSelectedMode(.myAccount, result: deeplink, animated: false)
        case .planPicker(let sectionId):
            navigateToPlanPicker(with: .deeplink(sectionId: sectionId))
        case .filteredPlanPicker(let productFilterData) where features.isEnabled(.targetedDeeplinksToPlanPicker):
            navigateToPlanPicker(with: .filteredDeeplink(productFilterData))
        default:
            mainViewController?.setSelectedMode(.browse, animated: false)
        }
        notifyChildren(deeplink: deeplink)
    }

    private func openSelectMode(_ sectionId: String) {
        if
            let mode = ViewingModeType(rawValue: sectionId),
            mainViewController?.isMenuItem(item: mode) == true
        {
            mainViewController?.setSelectedMode(mode, animated: false)
        } else {
            mainViewController?.setSelectedMode(.browse, animated: false)
            reporter.reportError(
                domain: AppErrorDomain.deeplink(),
                message: ErrorConstants.sectionNotAvailable,
                severity: .error,
                dependency: .clip
            )
        }
    }

    private func navigateToPlanPicker(with context: PlanPickerContext) {
        let planPickerCoordinator = PlanPickerCoordinator(
            context: context,
            hostViewController: mainViewController,
            presentationType: .present(animated: true)
        )
        addChildCoordinator(planPickerCoordinator)
        planPickerCoordinator.start()
    }
}

extension MainCoordinator {
    enum Action {
        case editProfile
        case onboarding
        case roadblock
    }

    struct Result {
        let persona: Persona?
        let action: Action
    }
}
