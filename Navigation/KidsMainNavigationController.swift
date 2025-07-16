import Analytics
import AppSettings_Api
import AppSettings_Impl
import ConcurrencyApi
import Core_Accessibility_Api
import Core_Accessibility_Impl
import Core_AppMetrics_Api
import Extensions
import PCLSLabelsApi
import PersonasApi
import UIKit

final class KidsMainNavigationController: BaseMainNavigationController {
    struct Constants {
        static let headerHeightCompact: CGFloat = 60
        static let headerHeightRegular: CGFloat = 84
    }

    private static let numberOfVCsPresentingFakeHeader: Int = 2
    private let upsellSceneFactory: UpsellSceneFactory
    private let pdpFactory: PDPFactoryProtocol
    private let imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol
    private let analytics: AnalyticsProtocol
    private let accessibility: Accessibility
    private var isRootLastViewControllerShown: Bool = true
    private let labels: Labels

    init(
        appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating? = nil,
        persona: Persona,
        messageCenter: MessagesCenter,
        features: Features = Dependency.resolve(Features.self),
        tracker: MainNavigationTracking = MainNavigationTracker(),
        upsellSceneFactory: UpsellSceneFactory,
        pdpFactory: PDPFactoryProtocol,
        imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol,
        analytics: AnalyticsProtocol = Dependency.resolve(AnalyticsProtocol.self),
        accessibility: Accessibility = AccessibilityImpl(),
        labels: Labels = Dependency.resolve(Labels.self),
        appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler
    ) {
        self.upsellSceneFactory = upsellSceneFactory
        self.pdpFactory = pdpFactory
        self.imageURLParametersGeneratorFactory = imageURLParametersGeneratorFactory
        self.analytics = analytics
        self.accessibility = accessibility
        self.labels = labels
        super.init(
            viewingModeControl: KidsBottomNavigationBar(analytics: analytics),
            appContainerAnimationCoordinator: appContainerAnimationCoordinator,
            persona: persona,
            messageCenter: messageCenter,
            features: features,
            tracker: tracker,
            appStartupMetrics: appStartupMetrics
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if viewingModeControl.selectedMode == nil {
            updateHeaderAccessibilityAccordingTo(mode: .browse)
            setInitialState(.browse)
        }

        addHeaderViewIfNeeded(view: header)
    }

    override func setupViewControllers() {
        super.setupViewControllers()
        updateLayout()
    }

    override func configure() {
        super.configure()

        let modes: [ViewingModeType] = [.downloads, .browse, .search]
        viewingModeControl.setModes(modes.map { ViewingModeControlConfiguration.makeKids($0) }, position: .center)
    }

    override func canPerformAppContainerAnimation() -> Bool {
        return true
    }

    override func reloadProfileButtonAccordingTo(mode: ViewingModeType) {
        appContainerAnimationCoordinator?.profileButtonContainer = header.profileButton
    }

    override func updateHeaderAccessibilityAccordingTo(mode: ViewingModeType) {
        header.setupAccessibility(
            with: labels.getLabel(forKey: LocalizationKeys.Accessibility.Logo.title),
            tabAccessibilityElement: nil
        )
        accessibility.postScreenChanged(header)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLayout()
    }

    private func updateLayout() {
        viewControllers.forEach { _, viewController in
            if let navigationController = viewController as? UINavigationController,
               let firstViewController = navigationController.viewControllers.first {
                firstViewController.additionalSafeAreaInsets.top = traitCollection.isRegularRegular ? Constants.headerHeightRegular : Constants.headerHeightCompact
            }
        }
    }

    private func updateHeaderViewAccessibilityIfNeeded(isRootNextViewController: Bool) {
        guard isRootLastViewControllerShown != isRootNextViewController else { return }
        configureAccessibility(isHeaderViewAccessible: isRootNextViewController)
    }
}

extension KidsMainNavigationController {

    override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)
        guard navigationController.viewControllers.count <= Self.numberOfVCsPresentingFakeHeader else { return }
        var fakeHeaderHolder: UIView?
        let addFakeHeader: ((_: UIViewController?) -> Void) = { [weak self] viewController in
            guard let self = self else { return }
            if let viewController = viewController,
               let fakeView = self.header.snapshotView(afterScreenUpdates: false) {
                fakeView.backgroundColor = .clear
                viewController.view.addSubview(fakeView)
                fakeView.frame = self.headerView.frame
                fakeHeaderHolder = fakeView
            }
        }

        let removeFakeHeader: (() -> Void) = {
            fakeHeaderHolder?.removeFromSuperview()
            fakeHeaderHolder = nil
        }

        addFakeHeader(navigationController.viewControllers.first)
        headerView.isHidden = true

        let isRootNextViewController = navigationController.viewControllers.first == viewController
        updateHeaderViewAccessibilityIfNeeded(isRootNextViewController: isRootNextViewController)
        isRootLastViewControllerShown = isRootNextViewController

        if let coordinator = viewController.transitionCoordinator {
            coordinator.animate { _ in }
            completion: { context in
                if isRootNextViewController && !context.isCancelled {
                    self.headerView.isHidden = false
                }
                removeFakeHeader()
            }
        } else {
            if isRootNextViewController {
                self.headerView.isHidden = false
            }
            removeFakeHeader()
        }
    }
}
