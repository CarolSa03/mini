// swiftlint:disable file_length
import Analytics
import ApplicationServiceState_Api
import AppLogoApi
import AppSettings_Api
import AppSettings_Impl
import ChannelGuideApi
import ChannelsApi
import ChromecastUi
import Collections_Api
import Combine
import ConcurrencyApi
import Core_Accessibility_Api
import Core_Accessibility_Impl
import Core_AppMetrics_Api
import Core_Common_Api
import Core_Data_Api
import Core_Ui_Ui
import DIManagerSwift
import Extensions
import Legacy_Api
import MainHeaderUi
import PCLSLabelsApi
import PCLSReachabilityApi
import PersonasApi
import UIKit

public typealias MainNavigationHandler = MainTabSwitcher & ChannelGuideDataPassing

public protocol ChannelGuideDataPassing: UIViewController {
    var channelGuideDataStore: GSTMobileChannelGuideDataStore? { get set }

    func updateStore(with channel: ChannelsApi.Channel, scheduleItem: ChannelsApi.ScheduleItem?, curatorInfo: CuratorInfo?, showInFullScreen: Bool, shouldResetRailPosition: Bool)
}

protocol NetworkLossErrorRetrying: UIViewController {}

public protocol MainTabSwitcher: UIViewController {
    func setSelectedMode(_ mode: ViewingModeType, result: Any?, animated: Bool, completion: (() -> Void)?)
    func getCurrentTabViewController() -> UIViewController?
}

public extension MainTabSwitcher {
    func setSelectedMode(_ mode: ViewingModeType, animated: Bool, completion: (() -> Void)?) {
        setSelectedMode(mode, result: nil, animated: animated, completion: completion)
    }
}

protocol MainNavigationRoutable: AnyObject {
    var router: MainNavigationRouting! { get set }
}

public protocol MainNavigationUpdatable: UIViewController {
    func add(viewController: UIViewController, for type: ViewingModeType)
}

protocol MainNavigationAnimatable: UIViewController {
    var viewControllers: [ViewingModeType: UIViewController] { get }
    var viewingModeControl: ViewingModeSelectionBar { get }
    var leftMarginConstraint: NSLayoutConstraint? { get set }
    var container: UIView! { get }

    var propertyAnimator: UIViewPropertyAnimator? { get set }
}

protocol MainNavigationContainer: MainNavigationUpdatable, MainNavigationAnimatable { }
// swiftlint:disable:next type_body_length
class BaseMainNavigationController: GSTMobileBaseViewController, MainNavigationContainer, MainNavigationRoutable, MainHeaderProvider {
    struct Constants {
        static let nibName = "BaseMainNavigationController"
        static let menuAnimationDuration: TimeInterval = 0.3
        static let viewingModeBottom: CGFloat = 36
        static let viewingModeSpacing: CGFloat = 16
        static let menuContainerHeightCompact: CGFloat = 84
        static let menuContainerHeightRegular: CGFloat = 76
        static let bottomGradientHeight: CGFloat = 120
        static let popupsDelay: TimeInterval = 2
    }

    let header: MainHeaderProtocol

    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var bottomGradientView: UIView!
    @IBOutlet weak private var containerBottomSpacingConstraint: NSLayoutConstraint!
    @IBOutlet weak private var gradientBottomSpacingConstraint: NSLayoutConstraint!

    private let menuContainerView = TouchableContainerView()

    private var viewingModeControlHeightConstraint: NSLayoutConstraint?
    private var viewingModeControlBottomConstraint: NSLayoutConstraint?
    private lazy var menuContainerHeightConstraint: NSLayoutConstraint = menuContainerView.heightAnchor.constraint(equalToConstant: Constants.menuContainerHeightCompact)
    let viewingModeControl: ViewingModeSelectionBar

    private let reachability: Reachability
    private var reachabilityState: NetworkReachabilityStatus?
    weak var channelGuideDataStore: GSTMobileChannelGuideDataStore?

    lazy var propertyAnimator: UIViewPropertyAnimator? = nil

    weak var appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating?
    let features: Features
    private let messageCenter: MessagesCenter
    private let tracker: MainNavigationTracking
    let persona: Persona
    private var menuContainerLastVisibilityState: Bool = true
    private let mainQueue: DispatchMainQueueable
    private let accessibility: Accessibility
    private var restrictedToDownloads: Bool = false
    private var subscription = Set<AnyCancellable>()
    private let observeAppServiceStateUseCase: any ObserveAppServiceStateUseCase
    private let getAppServiceStateUseCase: any GetAppServiceStateUseCase
    private let appServiceStateEnabled: Bool
    private let notificationCenter: NotificationCenterProtocol
    private let analytics: AnalyticsProtocol?
    private let appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler

    weak var leftMarginConstraint: NSLayoutConstraint?
    var viewControllers: [ViewingModeType: UIViewController] = [:]

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    var router: MainNavigationRouting!

    deinit {
        notificationCenter.removeObserver(self)
    }

    init(
        viewingModeControl: ViewingModeSelectionBar,
        appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating? = nil,
        persona: Persona,
        messageCenter: MessagesCenter,
        features: Features = Dependency.resolve(Features.self),
        tracker: MainNavigationTracking = MainNavigationTracker(),
        mainQueue: DispatchMainQueueable = DispatchQueue.main,
        reachability: Reachability = Dependency.resolve(Reachability.self),
        observeAppServiceStateUseCase: any ObserveAppServiceStateUseCase = Dependency.resolve((any ObserveAppServiceStateUseCase).self),
        getAppServiceStateUseCase: any GetAppServiceStateUseCase = Dependency.resolve((any GetAppServiceStateUseCase).self),
        accessibility: Accessibility = AccessibilityImpl(),
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default,
        analytics: AnalyticsProtocol? = nil,
        appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler
    ) {
        self.viewingModeControl = viewingModeControl
        self.appContainerAnimationCoordinator = appContainerAnimationCoordinator
        self.persona = persona
        self.messageCenter = messageCenter
        self.features = features
        self.tracker = tracker
        self.mainQueue = mainQueue
        self.reachability = reachability
        self.observeAppServiceStateUseCase = observeAppServiceStateUseCase
        self.getAppServiceStateUseCase = getAppServiceStateUseCase
        self.accessibility = accessibility
        appServiceStateEnabled = features.isEnabled(.dev(.appServiceState))
        self.notificationCenter = notificationCenter
        self.analytics = analytics
        self.appStartupMetrics = appStartupMetrics

        var buttonSet: ButtonOptions = [.chromecast, .profile]
        if
            !UIScreen.main.traitCollection.isRegularRegular,
            self.persona.type != .kid
        {
            buttonSet = []
        }
        self.header = MainHeader(
            for: persona,
            buttonSet: buttonSet,
            getAppLogoUseCase: Dependency.resolve((any GetAppLogoUseCase).self),
            labels: Dependency.resolve(Labels.self),
            observeCurrentPersonaUseCase: Dependency.resolve((any ObserveCurrentPersonaUseCase).self),
            observeLabelsUpdateUseCase: Dependency.resolve((any ObserveLabelsUpdateUseCase).self),
            mainScheduler: Dependency.resolve(name: .scheduler.main),
            chromecastButtonProvider: Dependency.resolve(Provider<ChromecastButton>.self)
        )
        super.init(nibName: Constants.nibName, bundle: .main)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Not available")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        configure()
        messageCenter.setCanForwardDeeplinks()
        appContainerAnimationCoordinator?.profileButtonContainer = header.profileButton
        appContainerAnimationCoordinator?.canAnimateToMain = { [weak self] in
            return self?.canPerformAppContainerAnimation() == true
        }
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        setupBottomGradient()
        configureAccessibility()
        setupObservers()

        mainQueue.asyncAfter(deadline: .now() + Constants.popupsDelay) { [weak self] in
            self?.router.showTransparencyPopupsIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let mode = viewingModeControl.selectedMode {
            reloadProfileButtonAccordingTo(mode: mode)
        }
        let isHidden = navigationController?.viewControllers.count == 1
        navigationController?.setNavigationBarHidden(isHidden, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        appContainerAnimationCoordinator?.profileButtonContainer = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let selectedMode = viewingModeControl.selectedMode {
            viewingModeControl.setSelectedMode(selectedMode, animated: false)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        let viewingModeControlHeight = ViewingModeMetrics.itemContainerHeight(for: traitCollection)
        viewingModeControlHeightConstraint = viewingModeControl.heightAnchor.constraint(equalToConstant: viewingModeControlHeight)
        let menuContainerHeight = traitCollection.isRegularRegular ? Constants.menuContainerHeightRegular : Constants.menuContainerHeightCompact
        menuContainerHeightConstraint.constant = menuContainerLastVisibilityState ? menuContainerHeight : 0
    }

    func setupViewControllers() {}

    func reloadProfileButtonAccordingTo(mode: ViewingModeType) {
        fatalError("reloadProfileButtonAccordingTo must be implemented")
    }

    func updateHeaderAccessibilityAccordingTo(mode: ViewingModeType) {}

    func add(viewController: UIViewController, for type: ViewingModeType) {
        if let navigationController = viewController as? UINavigationController {
            navigationController.delegate = self
        }
        viewControllers[type] = viewController
    }

    func configureAccessibility(isHeaderViewAccessible: Bool = true) {
        var accessibilityInfo: [AccessibilityObject] = isHeaderViewAccessible ? [.view(headerView)] : []
        accessibilityInfo.append(contentsOf: [.view(container), .view(menuContainerView)])
        view.configureAccessibilityElements(with: accessibilityInfo)
    }

    private func shouldDisplayDownloadsOffline() -> Bool {
        if appServiceStateEnabled {
            return restrictedToDownloads
        } else {
            return !reachability.networkReachabilityStatus.isReachable()
        }
    }

    func setInitialState(_ mode: ViewingModeType) {
        if appServiceStateEnabled {
            bindings()
            let viewingMode: ViewingModeType = restrictedToDownloads ? .downloads : mode
            viewingModeControl.setSelectedMode(viewingMode, animated: false)
            router.moveToViewingMode(viewingMode, animated: false) {
                self.accessibility.postLayoutChanged(self.viewingModeControl.selectedModeView)
            }

            if restrictedToDownloads {
                hideMenuContainer()
            }
        } else {
            reachabilityState = reachability.networkReachabilityStatus
            let offlineDownloadsMode = shouldDisplayDownloadsOffline()
            let viewingMode: ViewingModeType = offlineDownloadsMode ? .downloads : mode
            viewingModeControl.setSelectedMode(viewingMode, animated: false)
            router.moveToViewingMode(viewingMode, animated: false) {
                self.accessibility.postLayoutChanged(self.viewingModeControl.selectedModeView)
            }

            if offlineDownloadsMode {
                hideMenuContainer()
                DownloadsNotificationFactory.showNoNetworkNotification()
            }
        }
    }

    func configure() {
        view.addAutoLayoutSubviews(menuContainerView)
        menuContainerHeightConstraint.isActive = true

        let viewingModeControlHeight = ViewingModeMetrics.itemContainerHeight(for: traitCollection)
        viewingModeControl.delegate = self
        header.delegate = self
        viewingModeControl.translatesAutoresizingMaskIntoConstraints = false
        menuContainerView.addSubview(viewingModeControl)
        viewingModeControlBottomConstraint = viewingModeControl.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Constants.viewingModeBottom)
        viewingModeControlBottomConstraint?.isActive = true
        viewingModeControlHeightConstraint = viewingModeControl.heightAnchor.constraint(equalToConstant: viewingModeControlHeight)
        viewingModeControlHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            menuContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuContainerView.widthAnchor.constraint(equalTo: viewingModeControl.widthAnchor),

            viewingModeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            viewingModeControl.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Constants.viewingModeSpacing),
            viewingModeControl.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: Constants.viewingModeSpacing)
        ])

        guard !appServiceStateEnabled else { return }
        reachability.addObserver(self)
    }

    func addHeaderViewIfNeeded(view: UIView) {
        guard view.superview == nil else { return }
        headerView.isHidden = false
        headerView.backgroundColor = .clear
        headerView.subviews.forEach { $0.removeFromSuperview() }
        headerView.addSubviewAndPinEdges(view, toSafeArea: false)
        headerView.configureAccessibilityElements(with: [.view(view)])
    }

    func canPerformAppContainerAnimation() -> Bool {
        return !shouldDisplayDownloadsOffline()
    }

    func bindings() {
        observeAppServiceStateUseCase.execute()
            .sink(receiveValue: { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .offline:
                    self.restrictedToDownloads = true
                    self.mainQueue.async {
                        self.setDisplayMenuContainer(visible: false, animated: true)
                        self.displayOfflineDownloadDeeplinkableError()
                    }
                case .unavailable, .noAccess:
                    self.restrictedToDownloads = true
                    Player.stopAll(animated: false, nil)
                    self.mainQueue.async {
                        self.setDisplayMenuContainer(visible: false, animated: true)
                        self.setSelectedMode(.downloads, animated: true)
                    }
                case .available:
                    self.restrictedToDownloads = false
                    self.mainQueue.async {
                        self.setDisplayMenuContainer(visible: self.menuContainerLastVisibilityState, animated: true)
                        self.reloadCurrentViewController()
                        DownloadsNotificationFactory.dismissNotification()
                    }
                }
            })
            .store(in: &subscription)
    }
}

private extension BaseMainNavigationController {

    private func hideMenuContainer() {
        menuContainerView.isHidden = true
        menuContainerView.isUserInteractionEnabled = false
    }

    private func updateState(for state: NetworkReachabilityStatus) {
        guard
            !appServiceStateEnabled,
            state != reachabilityState
        else {
            return
        }

        if state == .notReachable {
            displayOfflineDownloadDeeplinkableError()
            setDisplayMenuContainer(visible: false, animated: true)
        } else if reachabilityState == .notReachable {
            // We previously had no connection, but now we do.
            reloadCurrentViewController()
            // We have connection, so we should make sure the nav bar is visible
            setDisplayMenuContainer(visible: menuContainerLastVisibilityState, animated: true)
            DownloadsNotificationFactory.dismissNotification()
        }
        reachabilityState = state
    }

    private func updateInsetsForMenuContainer(visible: Bool) {
        let menuContainerTopMargin = traitCollection.isRegularRegular ? max(0, Constants.bottomGradientHeight - menuContainerView.height) : 0
        let bottomInset = visible ? view.height - menuContainerView.y + menuContainerTopMargin : 0
        children.forEach { vc in
            vc.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        }
    }

    private func setDisplayMenuContainer(visible: Bool, animated: Bool) {
        updateInsetsForMenuContainer(visible: visible)

        let menuContainerHeight = traitCollection.isRegularRegular ? Constants.menuContainerHeightRegular : Constants.menuContainerHeightCompact
        menuContainerView.isHidden = false
        bottomGradientView.isHidden = false
        bottomGradientView.isUserInteractionEnabled = false
        menuContainerHeightConstraint.constant = menuContainerHeight
        viewingModeControlBottomConstraint?.constant = visible ? -Constants.viewingModeBottom : menuContainerHeight + viewingModeControl.height
        UIView.animate(withDuration: animated ? Constants.menuAnimationDuration : 0) {
            self.menuContainerView.layoutIfNeeded()
            self.bottomGradientView.alpha = visible ? 1 : 0
        } completion: { [weak self] _ in
            self?.menuContainerView.isHidden = !visible
            self?.bottomGradientView.isHidden = !visible
            self?.menuContainerHeightConstraint.constant = visible ? menuContainerHeight : 0
            self?.menuContainerView.isUserInteractionEnabled = visible
        }
    }

    private func setDisplayMenuContainerUsingValidation(visible: Bool, animated: Bool) {
        if appServiceStateEnabled {
            guard (restrictedToDownloads && !visible) || !restrictedToDownloads else { return }
        } else {
            let isReachable = self.reachability.networkReachabilityStatus.isReachable()
            guard (!isReachable && !visible) || isReachable else { return }
        }

        setDisplayMenuContainer(visible: visible, animated: animated)
    }

    private func displayOfflineDownloadDeeplinkableError() {
        // check both BaseNav and Application-level topViewControllers for conformance to NetworkLossErrorRetrying
        let allowRetry = ![topViewController, UIApplication.shared.topViewController()].compactMap({ $0 as? NetworkLossErrorRetrying }).isEmpty

        guard !allowRetry else {
            DownloadsNotificationFactory.showOfflineDeeplinkError(retryAction: attemptToReloadCurrentViewControllerIfNeeded) { [weak self] in
                guard let self = self else { return }
                // dismiss for player and upsell page
                self.dismiss(animated: true) {
                    DownloadsNotificationFactory.showOfflineDeeplinkDownloadsError()
                }
            }
            return
        }

        setSelectedMode(.downloads, animated: true) {
            Player.stopAll(animated: false) {
                DownloadsNotificationFactory.showOfflineDeeplinkDownloadsError()
            }
        }
    }

    private func attemptToReloadCurrentViewControllerIfNeeded() {
        let isOffline = appServiceStateEnabled ? getAppServiceStateUseCase.execute() == .offline : reachabilityState == .notReachable

        if isOffline {
            displayOfflineDownloadDeeplinkableError()
        } else {
            reloadCurrentViewController()
        }
    }

    private func setupBottomGradient() {
        let colors: [UIColor] = [Theme.GradientView.First.endColor,
                                 Theme.GradientView.First.startColor.withAlphaComponent(0.8)]
        let colors2: [UIColor] = [Theme.GradientView.Second.startColor, Theme.GradientView.Second.endColor]
        let gradient2 = Gradient(startPoint: nil,
                                 endPoint: nil,
                                 locations: nil,
                                 colors: colors2)
        bottomGradientView.addGradient(gradient2)

        let gradient = Gradient(startPoint: nil,
                                endPoint: nil,
                                locations: nil,
                                colors: colors)
        bottomGradientView.addGradient(gradient)
    }

    private func setupObservers() {
        notificationCenter.addObserver(self,
                                       selector: #selector(voiceOverStatusDidChange),
                                       name: UIAccessibility.voiceOverStatusDidChangeNotification,
                                       object: nil)
    }

    @objc
    private func voiceOverStatusDidChange() {
        UIView.animate(withDuration: Constants.menuAnimationDuration) { [weak self] in
            guard let self = self else { return }
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.accessibility.postLayoutChanged(self)
        }
    }
}

extension BaseMainNavigationController: MainTabSwitcher {
    func setSelectedMode(_ mode: ViewingModeType, result: Any? = nil, animated: Bool, completion: (() -> Void)? = nil) {
        reloadProfileButtonAccordingTo(mode: mode)
        updateHeaderAccessibilityAccordingTo(mode: mode)

        viewingModeControl.setSelectedMode(mode, animated: animated)
        router.moveToViewingMode(mode, animated: animated, completion: completion)
        menuContainerLastVisibilityState = true
    }

    func getCurrentTabViewController() -> UIViewController? {
        router.getCurrentTabViewController()
    }

    private func reloadCurrentViewController() {
        if let reloadableViewController = navigationController?.topViewController as? MainNavigationReloadable {
            reloadableViewController.reloadData()
        } else if let selectedMode = viewingModeControl.selectedMode,
            let reloadableViewController = viewControllers[selectedMode] as? MainNavigationReloadable {
            reloadableViewController.reloadData()
        }
    }
}

extension BaseMainNavigationController: ChannelGuideDataPassing {
    func updateStore(
        with channel: Channel,
        scheduleItem: ScheduleItem?,
        curatorInfo: CuratorInfo?,
        showInFullScreen: Bool,
        shouldResetRailPosition: Bool
    ) {
        channelGuideDataStore?.preselectedChannelGuideData = PreselectedChannelGuideData(
            channel: channel,
            scheduleItem: scheduleItem,
            curatorInfo: curatorInfo,
            startInFullscreen: showInFullScreen,
            resetListPosition: shouldResetRailPosition
        )
    }
}

extension BaseMainNavigationController: ViewingModeSelectionBarDelegate {
    func didSelectMode(_ mode: ViewingModeType) {
        tracker.trackItemSelected(viewModeType: mode)
        stopTrackingApplicationStartup()
        menuContainerLastVisibilityState = true
        setSelectedMode(mode, animated: true, completion: { [weak self] in
            guard let self = self else { return }
            self.updateState(for: self.reachability.networkReachabilityStatus)
        })
    }
}

extension BaseMainNavigationController: MainHeaderDelegate {
    func didTapLogo() {
        guard persona.type != .kid else { return }
        router.resetToInitialTabIfNeeded(scrollToTop: true)
        router.scrollInitialTabToTopIfNeeded(animated: true)
        analytics?.track(event: .navigation(.peacockLogoTapped))
    }

    func didTapProfileButton() {
        stopTrackingApplicationStartup()
        router.openProfiles()
    }

    func didTapMyAccountButton() {
        tracker.trackItemSelected(viewModeType: .myAccount)
        router.moveToViewingMode(.myAccount, animated: true, completion: nil)
        reloadCurrentViewController()
    }
}

extension BaseMainNavigationController: ReachabilityObserver {
    func reachabilityDidChange(from oldStatus: NetworkReachabilityStatus?, to newValue: NetworkReachabilityStatus) {
        mainQueue.async { [weak self] in
            self?.updateState(for: newValue)
        }
    }
}

private extension BaseMainNavigationController {
    private func stopTrackingApplicationStartup() {
        appStartupMetrics.stopTrackingApplicationStartup(on: .browse(browseAction: .menuClick))
    }
}

extension BaseMainNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if let statusBarHideableViewController = viewController as? NavigationBarHideable {
            if let coordinator = viewController.transitionCoordinator {
                coordinator.animate { context in
                    self.setDisplayMenuContainerUsingValidation(visible: statusBarHideableViewController.shouldShowMainNavigationBar, animated: animated)
                } completion: { context in
                    if !context.isCancelled {
                        self.menuContainerLastVisibilityState = statusBarHideableViewController.shouldShowMainNavigationBar
                    }
                    self.setDisplayMenuContainerUsingValidation(visible: self.menuContainerLastVisibilityState, animated: animated)
                }
            } else {
                self.setDisplayMenuContainerUsingValidation(visible: statusBarHideableViewController.shouldShowMainNavigationBar, animated: animated)
            }
        }
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if let statusBarHideableViewController = viewController as? GSTMobileBaseViewController {
            self.setDisplayMenuContainerUsingValidation(visible: statusBarHideableViewController.shouldShowMainNavigationBar, animated: animated)
        }
    }
}

private extension BaseMainNavigationController {
    var topViewController: UIViewController? {
        var childVc = router.getCurrentTabViewController()
        while let nav = childVc as? UINavigationController {
            childVc = nav.topViewController
        }
        return childVc
    }
}
