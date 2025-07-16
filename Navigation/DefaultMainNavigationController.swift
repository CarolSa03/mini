import Analytics
import AppSettings_Api
import AppSettings_Impl
import Core_AppMetrics_Api
import Foundation
import PersonasApi

final class DefaultMainNavigationController: BaseMainNavigationController {
    private let upsellSceneFactory: UpsellSceneFactory
    private let pdpFactory: PDPFactoryProtocol
    private let imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol
    private let analytics: AnalyticsProtocol

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
        appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler
    ) {
        self.upsellSceneFactory = upsellSceneFactory
        self.pdpFactory = pdpFactory
        self.imageURLParametersGeneratorFactory = imageURLParametersGeneratorFactory
        self.analytics = analytics
        super.init(
            viewingModeControl: DefaultBottomNavigationBar(analytics: analytics),
            appContainerAnimationCoordinator: appContainerAnimationCoordinator,
            persona: persona,
            messageCenter: messageCenter,
            features: features,
            tracker: tracker,
            analytics: analytics,
            appStartupMetrics: appStartupMetrics
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if viewingModeControl.selectedMode == nil {
            setInitialState(.browse)
        }
    }

    override func configure() {
        super.configure()

        viewingModeControl.setModes([ViewingModeControlConfiguration.make(.downloads)],
                                    position: .left)

        let center: [ViewingModeType] = features.isEnabled(.isChannelsEnabled) ? [.browse, .channels] : [.browse]
        viewingModeControl.setModes(center.map { ViewingModeControlConfiguration.make($0) }, position: .center)

        viewingModeControl.setModes([ViewingModeControlConfiguration.make(.search)],
                                    position: .right)
    }

    override func reloadProfileButtonAccordingTo(mode: ViewingModeType) {
        if mode == .browse {
            appContainerAnimationCoordinator?.profileButtonContainer = header.profileButton
        } else {
            appContainerAnimationCoordinator?.profileButtonContainer = nil
        }
    }
}
