// swiftlint:disable file_length
import AccessibilityApi
import Account_Api
import AccountApi
import Analytics
import AppReportingApi
import AppSettings_Api
import AppSettings_Impl
import Browse_Api
import BrowseApi
import ChannelGuideApi
import ChannelsApi
import ChromecastApi
import Collections_Api
import Collections_Impl
import CombineSchedulers
import ConcurrencyApi
import Core_AppMetrics_Api
import Core_Common_Api
import Core_Common_Impl
import Core_Images_Api
import Core_Ui_Api
import DownloadsApi
import GamesUi
import Impressions_Api
import Legacy_Api
import Legacy_Impl
import Localisation_Api
import Localisation_Impl
import MainHeaderUi
import MainMenu_Api
import MainMenu_Impl
import OnboardingApi
import PCLSLabelsApi
import PCLSLocalisationApi
import PCLSReachabilityApi
import PersonasApi
import PlayerContextApi
import PlayerCoreApi
import PlayerSharedApi
import TimeApi
import TypographyApi
import UIKit
import UserOnboarding_Api
import Widget_Impl

protocol MainCoordinatorFactoryProtocol {
    func makeMainTabBarViewController() -> MainTabBarViewController
    func makeLegacyMainViewController() -> BaseMainNavigationController
    func makeBrowseCoordinator(hostViewController: MainNavigationUpdatable, mainNavigationHandler: MainNavigationHandler, mainTabBarHeightFromBottom: CGFloat?) -> Coordinator
    func makeSearchCoordinator(hostViewController: MainNavigationUpdatable, mainNavigationHandler: MainNavigationHandler) -> Coordinator
    func makeChannelGuideCoordinator(hostViewController: MainNavigationUpdatable & ChannelGuideDataPassing, mainNavigationHandler: MainNavigationHandler) -> Coordinator
    func makeDownloadsCoordinator(hostViewController: MainNavigationUpdatable) -> Coordinator
    func makePlayerNavigationHandler(mainNavigationHandler: MainNavigationHandler, mainNavigationDelegate: MainNavigationDelegate?) -> PlayerNavigationHandling
    func makeMyAccountCoordinator(hostViewController: AppContainerViewControllerProtocol) -> Coordinator
}

struct MainCoordinatorFactory {
    struct Dependencies {
        let appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating?
        let persona: Persona
        let messageCenter: MessagesCenter
        let downloadManager: DownloadManager
        let upsellSceneFactory: any UpsellSceneFactory
        let pdpFactory: PDPFactoryProtocol
        let gameFactory: GameFactory
        let getChannelByKeyUseCase: any GetChannelByKeyUseCase
        let getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase
        let observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase
        let observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase
        let observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase
        let observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase
        let imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol
        let imageLoader: ImageLoader
        let notificationCenter: NotificationCenterProtocol
        let analytics: AnalyticsProtocol
        let appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler
        let features: Features
        let fetchRailLevelUseCase: any FetchRailLevelUseCase
        let adapterWapper: LegacyAdapterWrapper
        let userDetailsRepository: UserDetailsRepository
        let mainTabBarViewFactory: MainTabBarViewFactory
        let impressionsCollectorFactory: any ImpressionsCollectorFactory
        let labels: Labels
        let playContextFactory: PlayContextFactory
        let fetchAccessibilityLabelUseCase: any FetchAccessibilityLabelUseCase
        let fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase
        let fetchRailGridUseCase: any FetchRailGridUseCase
        let observeTilesUseCase: any ObserveBrowseTilesUseCase
        let resolveTileUseCase: any ResolveTileUseCase
        let taskRunner: ConcurrencyTaskRunner
        let voiceAICoordinator: Factory<VoiceAICoordinator, UIViewController>
        let lazyLoadingCollectionGridCoordinatorFactory: Factory<LazyLoadingCollectionGridCoordinatorV2, LazyLoadingCollectionGridCoordinatorV2Input>
        let lazyLoadingCollectionGroupCoordinatorFactory: Factory<LazyLoadingCollectionGroupCoordinator, LazyLoadingCollectionGroupCoordinatorInput>
        let chromecastManager: ChromecastManager
        let browseCoodinatorFactory: Factory<BrowseCoordinator, BrowseCoordinatorInput>
        let trackingTransparency: TrackingTransparency
        let channelsViewControllerFactory: ChannelGuideV2ViewControllerFactory
        let miniPDPCoordinatorFactory: Factory<any MiniPDPCoordinator, MiniPDPCoordinatorInput>
        let fetchUserSubscriptionStatusUseCase: any FetchUserSubscriptionStatusUseCase

        init(
            appContainerAnimationCoordinator: AppContainerMainAnimationCoordinating?,
            persona: Persona,
            messageCenter: MessagesCenter,
            downloadManager: DownloadManager = Dependency.resolve(DownloadManager.self),
            upsellSceneFactory: UpsellSceneFactory,
            pdpFactory: PDPFactoryProtocol,
            gameFactory: any GameFactory = Dependency.resolve((any GameFactory).self),
            getChannelByKeyUseCase: any GetChannelByKeyUseCase = Dependency.resolve((any GetChannelByKeyUseCase).self),
            getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase = Dependency.resolve((any GetChannelsMenuSectionNavigationUseCase).self),
            observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase = Dependency.resolve((any ObserveLocalisationTerritoryChangesUseCase).self),
            observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase = Dependency.resolve((any ObserveLocalisationBouquetChangesUseCase).self),
            observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase = Dependency.resolve((any ObserveServerTimeOffsetChangesUseCase).self),
            observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase = Dependency.resolve((any ObserveUserDetailsChangesUseCase).self),
            imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol,
            imageLoader: ImageLoader,
            notificationCenter: NotificationCenterProtocol = NotificationCenter.default,
            analytics: AnalyticsProtocol = Dependency.resolve(AnalyticsProtocol.self),
            appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler,
            features: Features,
            fetchRailLevelUseCase: any FetchRailLevelUseCase = Dependency.resolve((any FetchRailLevelUseCase).self),
            adapterWapper: LegacyAdapterWrapper = Dependency.resolve(LegacyAdapterWrapper.self),
            userDetailsRepository: UserDetailsRepository = Dependency.resolve(UserDetailsRepository.self),
            mainTabBarViewFactory: MainTabBarViewFactory,
            impressionsCollectorFactory: any ImpressionsCollectorFactory,
            labels: Labels,
            playContextFactory: PlayContextFactory = Dependency.resolve(PlayContextFactory.self),
            fetchAccessibilityLabelUseCase: any FetchAccessibilityLabelUseCase = Dependency.resolve((any FetchAccessibilityLabelUseCase).self),
            fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase = Dependency.resolve((any FetchBrowseTilesUseCase).self),
            fetchRailGridUseCase: any FetchRailGridUseCase = Dependency.resolve((any FetchRailGridUseCase).self),
            observeTilesUseCase: any ObserveBrowseTilesUseCase = Dependency.resolve((any ObserveBrowseTilesUseCase).self),
            resolveTileUseCase: any ResolveTileUseCase = Dependency.resolve((any ResolveTileUseCase).self),
            taskRunner: ConcurrencyTaskRunner = Dependency.resolve(ConcurrencyTaskRunner.self),
            voiceAICoordinator: Factory<VoiceAICoordinator, UIViewController> = Dependency.resolve(Factory<VoiceAICoordinator, UIViewController>.self),
            lazyLoadingCollectionGridCoordinatorFactory: Factory<LazyLoadingCollectionGridCoordinatorV2, LazyLoadingCollectionGridCoordinatorV2Input> = Dependency.resolve(Factory<LazyLoadingCollectionGridCoordinatorV2, LazyLoadingCollectionGridCoordinatorV2Input>.self),
            lazyLoadingCollectionGroupCoordinatorFactory: Factory<LazyLoadingCollectionGroupCoordinator, LazyLoadingCollectionGroupCoordinatorInput> = Dependency.resolve(Factory<LazyLoadingCollectionGroupCoordinator, LazyLoadingCollectionGroupCoordinatorInput>.self),
            chromecastManager: ChromecastManager = Dependency.resolve(ChromecastManager.self),
            browseCoodinatorFactory: Factory<BrowseCoordinator, BrowseCoordinatorInput>,
            trackingTransparency: TrackingTransparency,
            channelsViewControllerFactory: ChannelGuideV2ViewControllerFactory = Dependency.resolve(),
            miniPDPCoordinatorFactory: Factory<any MiniPDPCoordinator, MiniPDPCoordinatorInput> = Dependency.resolve(),
            fetchUserSubscriptionStatusUseCase: any FetchUserSubscriptionStatusUseCase = Dependency.resolve((any FetchUserSubscriptionStatusUseCase).self)
        ) {
            self.appContainerAnimationCoordinator = appContainerAnimationCoordinator
            self.persona = persona
            self.messageCenter = messageCenter
            self.downloadManager = downloadManager
            self.upsellSceneFactory = upsellSceneFactory
            self.pdpFactory = pdpFactory
            self.gameFactory = gameFactory
            self.getChannelByKeyUseCase = getChannelByKeyUseCase
            self.getChannelsMenuSectionNavigationUseCase = getChannelsMenuSectionNavigationUseCase
            self.observeLocalisationTerritoryChangesUseCase = observeLocalisationTerritoryChangesUseCase
            self.observeLocalisationBouquetChangesUseCase = observeLocalisationBouquetChangesUseCase
            self.observeServerTimeOffsetChangesUseCase = observeServerTimeOffsetChangesUseCase
            self.observeUserDetailsChangesUseCase = observeUserDetailsChangesUseCase
            self.imageURLParametersGeneratorFactory = imageURLParametersGeneratorFactory
            self.imageLoader = imageLoader
            self.notificationCenter = notificationCenter
            self.analytics = analytics
            self.appStartupMetrics = appStartupMetrics
            self.features = features
            self.fetchRailLevelUseCase = fetchRailLevelUseCase
            self.adapterWapper = adapterWapper
            self.userDetailsRepository = userDetailsRepository
            self.mainTabBarViewFactory = mainTabBarViewFactory
            self.impressionsCollectorFactory = impressionsCollectorFactory
            self.labels = labels
            self.playContextFactory = playContextFactory
            self.fetchAccessibilityLabelUseCase = fetchAccessibilityLabelUseCase
            self.fetchBrowseTilesUseCase = fetchBrowseTilesUseCase
            self.fetchRailGridUseCase = fetchRailGridUseCase
            self.observeTilesUseCase = observeTilesUseCase
            self.resolveTileUseCase = resolveTileUseCase
            self.taskRunner = taskRunner
            self.voiceAICoordinator = voiceAICoordinator
            self.lazyLoadingCollectionGridCoordinatorFactory = lazyLoadingCollectionGridCoordinatorFactory
            self.lazyLoadingCollectionGroupCoordinatorFactory = lazyLoadingCollectionGroupCoordinatorFactory
            self.chromecastManager = chromecastManager
            self.browseCoodinatorFactory = browseCoodinatorFactory
            self.trackingTransparency = trackingTransparency
            self.channelsViewControllerFactory = channelsViewControllerFactory
            self.miniPDPCoordinatorFactory = miniPDPCoordinatorFactory
            self.fetchUserSubscriptionStatusUseCase = fetchUserSubscriptionStatusUseCase
        }
    }
    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
}

extension MainCoordinatorFactory: MainCoordinatorFactoryProtocol {
    func makeMainTabBarViewController() -> MainTabBarViewController {
        return MainTabBarViewController(
            mainTabBarViewFactory: dependencies.mainTabBarViewFactory,
            appContainerAnimationCoordinator: dependencies.appContainerAnimationCoordinator,
            persona: dependencies.persona,
            downloadManager: dependencies.downloadManager,
            appStartupMetrics: dependencies.appStartupMetrics
        )
    }

    func makeLegacyMainViewController() -> BaseMainNavigationController {
        switch dependencies.persona.type {
        case .kid:
            return KidsMainNavigationController(
                appContainerAnimationCoordinator: dependencies.appContainerAnimationCoordinator,
                persona: dependencies.persona,
                messageCenter: dependencies.messageCenter,
                upsellSceneFactory: dependencies.upsellSceneFactory,
                pdpFactory: dependencies.pdpFactory,
                imageURLParametersGeneratorFactory: dependencies.imageURLParametersGeneratorFactory,
                analytics: dependencies.analytics,
                appStartupMetrics: dependencies.appStartupMetrics
            )

        case .teen,
             .adult:
            return DefaultMainNavigationController(
                appContainerAnimationCoordinator: dependencies.appContainerAnimationCoordinator,
                persona: dependencies.persona,
                messageCenter: dependencies.messageCenter,
                upsellSceneFactory: dependencies.upsellSceneFactory,
                pdpFactory: dependencies.pdpFactory,
                imageURLParametersGeneratorFactory: dependencies.imageURLParametersGeneratorFactory,
                analytics: dependencies.analytics,
                appStartupMetrics: dependencies.appStartupMetrics
            )
        }
    }

    func makeBrowseCoordinator(hostViewController: MainNavigationUpdatable, mainNavigationHandler: MainNavigationHandler, mainTabBarHeightFromBottom: CGFloat?) -> Coordinator {
        guard
            dependencies.features.isEnabled(.personalizedBrowseFinal)
        else {
            return makeLegacyBrowseCoordinator(
                hostViewController: hostViewController,
                mainNavigationHandler: mainNavigationHandler,
                mainTabBarHeightFromBottom: mainTabBarHeightFromBottom
            )
        }

        let input = BrowseCoordinatorInput(
            persona: dependencies.persona,
            hostViewController: hostViewController,
            mainNavigationHandler: mainNavigationHandler
        )
        return dependencies.browseCoodinatorFactory.make(input)
    }

    // swiftlint:disable:next function_body_length
    private func makeLegacyBrowseCoordinator(hostViewController: MainNavigationUpdatable, mainNavigationHandler: MainNavigationHandler, mainTabBarHeightFromBottom: CGFloat?) -> Coordinator {
        let header = (mainNavigationHandler as? MainHeaderProvider)?.header
        let browseFactory = LegacyBrowseCoordinatorFactory(
            dependencies: .init(
                features: dependencies.features,
                upsellSceneFactory: dependencies.upsellSceneFactory,
                pdpFactory: dependencies.pdpFactory,
                gameFactory: dependencies.gameFactory,
                jumbotronFactory: JumbotronFactory(),
                observeLocalisationTerritoryChangesUseCase: dependencies.observeLocalisationTerritoryChangesUseCase,
                observeLocalisationBouquetChangesUseCase: dependencies.observeLocalisationBouquetChangesUseCase,
                observeServerTimeOffsetChangesUseCase: dependencies.observeServerTimeOffsetChangesUseCase,
                observeUserDetailsChangesUseCase: dependencies.observeUserDetailsChangesUseCase,
                imageURLParametersGeneratorFactory: dependencies.imageURLParametersGeneratorFactory,
                imageLoader: dependencies.imageLoader,
                persona: dependencies.persona,
                header: header,
                player: Player.shared,
                mainNavigationHandler: mainNavigationHandler,
                assetActionValidator: Dependency.resolve(AssetActionValidating.self),
                appStoreReview: Dependency.resolve(AppStoreReviewManager.self),
                freeWheelAnd3PTracker: Dependency.resolve(AssetFreeWheelAnd3PTracker.self),
                reachability: Dependency.resolve(Reachability.self),
                analytics: dependencies.analytics,
                appStartupMetrics: dependencies.appStartupMetrics,
                appMetricsManager: Dependency.resolve(AppMetricsManager.self),
                setOnboardingUseCase: Dependency.resolve((any SetOnboardingUseCase).self),
                fetchAccessibilityLabelUseCase: dependencies.fetchAccessibilityLabelUseCase,
                labels: dependencies.labels,
                uiAuditorManagerFactory: Dependency.resolve(
                    (any UIAuditorManagerFactoryV1).self,
                    args: AppErrorDomain.browse().asAnyErrorDomain()
                ),
                fetchUserSubscriptionStatusUseCase: dependencies.fetchUserSubscriptionStatusUseCase
            )
        )

        return LegacyBrowseCoordinator(
            dependencies: LegacyBrowseCoordinator.Dependencies(
                persona: dependencies.persona,
                upsellSceneFactory: dependencies.upsellSceneFactory,
                factory: browseFactory,
                analytics: dependencies.analytics,
                hostViewController: hostViewController,
                mainNavigationHandler: mainNavigationHandler,
                features: dependencies.features,
                playContextFactory: dependencies.playContextFactory,
                chromecastManager: dependencies.chromecastManager,
                voiceAICoordinator: dependencies.voiceAICoordinator,
                lazyLoadingCollectionGridCoordinatorFactory: dependencies.lazyLoadingCollectionGridCoordinatorFactory,
                lazyLoadingCollectionGroupCoordinatorFactory: dependencies.lazyLoadingCollectionGroupCoordinatorFactory,
                miniPDPCoordinatorFactory: dependencies.miniPDPCoordinatorFactory,
                convertLegacyChannelUseCase: Dependency.resolve((any ConvertLegacyChannelUseCase).self),
                mainScheduler: Dependency.resolve(name: .scheduler.main),
                mainTabBarHeightFromBottom: mainTabBarHeightFromBottom,
                watchlistErrorNotificationFactory: Dependency.resolve(type: ErrorNotificationProtocol.self, name: .errorNotificationName.watchlist),
                subscriptionOnHoldFactory: Dependency.resolve((any SubscriptionOnHoldRoadblockFactoryProtocol).self),
                gamesCoordinatorFactory: Dependency.resolve(Factory<GamesCoordinator, GamesCoordinatorInput>.self)
            )
        )
    }

    func makeSearchCoordinator(hostViewController: MainNavigationUpdatable, mainNavigationHandler: MainNavigationHandler) -> Coordinator { // swiftlint:disable:this function_body_length
        let observeSearchEmptyStateUseCase: any ObserveSearchEmptyStateUseCase = ObserveSearchEmptyStateUseCaseImpl(
            fetchRailLevelUseCase: dependencies.fetchRailLevelUseCase,
            adapterWrapper: dependencies.adapterWapper,
            collectionLinearSlotEnricher: CollectionLinearSlotEnricherImpl(
                adapterWapper: dependencies.adapterWapper,
                observeChannelsUseCase: Dependency.resolve((any ObserveChannelsUseCase).self),
                getChannelsMenuSectionNavigationUseCase: Dependency.resolve((any GetChannelsMenuSectionNavigationUseCase).self)
            )
        )
        let searchRepository: SearchRepository = SearchRepositoryImpl(
            adapterWrapper: dependencies.adapterWapper,
            userRecentSearchesStore: UserRecentSearchesStoreImpl.shared,
            features: dependencies.features,
            taskRunner: Dependency.resolve(ConcurrencyTaskRunner.self)
        )
        let observeSearchAssetsUseCase: any ObserveSearchAssetsUseCase = ObserveSearchAssetsUseCaseImpl(
            searchRepository: searchRepository,
            userDetailsRepository: dependencies.userDetailsRepository,
            getDiscoveryContentSegmentsUseCase: Dependency.resolve(type: (any GetDiscoveryContentSegmentsUseCase).self, name: .discovery.default),
            getPlayoutContentSegmentsUseCase: Dependency.resolve((any GetPlayoutContentSegmentsUseCase).self),
            configs: Dependency.resolve(Configs.self),
            features: dependencies.features,
            currentPersona: dependencies.persona
        )

        let addRecentSearchTermUseCase: any AddRecentSearchTermUseCase = AddRecentSearchTermUseCaseImpl(
            searchRepository: searchRepository,
            currentPersona: dependencies.persona
        )
        let getRecentSearchesUseCase: any GetRecentSearchesUseCase = GetRecentSearchesUseCaseImpl(
            searchRepository: searchRepository,
            currentPersona: dependencies.persona
        )

        let searchFactory = SearchCoordinatorFactory(
            dependencies: .init(
                features: dependencies.features,
                upsellSceneFactory: dependencies.upsellSceneFactory,
                pdpFactory: dependencies.pdpFactory,
                getChannelByKeyUseCase: dependencies.getChannelByKeyUseCase,
                getChannelsMenuSectionNavigationUseCase: dependencies.getChannelsMenuSectionNavigationUseCase,
                observeLocalisationTerritoryChangesUseCase: dependencies.observeLocalisationTerritoryChangesUseCase,
                observeLocalisationBouquetChangesUseCase: dependencies.observeLocalisationBouquetChangesUseCase,
                observeServerTimeOffsetChangesUseCase: dependencies.observeServerTimeOffsetChangesUseCase,
                observeUserDetailsChangesUseCase: dependencies.observeUserDetailsChangesUseCase,
                appStartupMetrics: dependencies.appStartupMetrics,
                imageURLParametersGeneratorFactory: dependencies.imageURLParametersGeneratorFactory,
                imageLoader: dependencies.imageLoader,
                persona: dependencies.persona,
                player: Player.shared,
                mainNavigationHandler: mainNavigationHandler,
                assetActionValidator: Dependency.resolve(AssetActionValidating.self),
                appStoreReview: Dependency.resolve(AppStoreReviewManager.self),
                freeWheelAnd3PTracker: Dependency.resolve(AssetFreeWheelAnd3PTracker.self),
                reachability: Dependency.resolve(Reachability.self),
                analytics: dependencies.analytics,
                appMetricsManager: Dependency.resolve(AppMetricsManager.self),
                getSearchMenuItemUseCase: Dependency.resolve((any GetSearchMenuItemUseCase).self),
                observeSearchAssetsUseCase: observeSearchAssetsUseCase,
                addRecentSearchTermUseCase: addRecentSearchTermUseCase,
                getRecentSearchesUseCase: getRecentSearchesUseCase,
                observeSearchEmptyStateUseCase: observeSearchEmptyStateUseCase,
                labels: dependencies.labels,
                tilesFactory: Dependency.resolve((any SearchTilesFactory).self),
                fetchAccessibilityLabelUseCase: dependencies.fetchAccessibilityLabelUseCase,
                fetchBrowseTilesUseCase: dependencies.fetchBrowseTilesUseCase,
                fetchRailGridUseCase: dependencies.fetchRailGridUseCase,
                observeTilesUseCase: dependencies.observeTilesUseCase,
                resolveTileUseCase: dependencies.resolveTileUseCase,
                taskRunner: dependencies.taskRunner
            )
        )
        return SearchCoordinator(
            hostViewController: hostViewController,
            mainNavigationHandler: mainNavigationHandler,
            factory: searchFactory,
            features: Dependency.resolve(Features.self),
            playContextFactory: Dependency.resolve(PlayContextFactory.self),
            convertLegacyChannelUseCase: Dependency.resolve((any ConvertLegacyChannelUseCase).self),
            miniPDPCoordinatorFactory: dependencies.miniPDPCoordinatorFactory,
            mainScheduler: DispatchQueue.main.eraseToAnyScheduler(),
            persona: dependencies.persona,
            upsellSceneFactory: dependencies.upsellSceneFactory
        )
    }

    func makeChannelGuideCoordinator(hostViewController: MainNavigationUpdatable & ChannelGuideDataPassing, mainNavigationHandler: MainNavigationHandler) -> Coordinator {
        let isChannelNeighborhoodsEnabled = dependencies.features.isEnabled(.channel(.channelGuideSections))
        if isChannelNeighborhoodsEnabled {
            return ChannelGuideCoordinatorV2(
                hostViewController: hostViewController,
                viewControllerFactory: dependencies.channelsViewControllerFactory,
                getChannelByKeyUseCase: dependencies.getChannelByKeyUseCase,
                getChannelsMenuSectionNavigationUseCase: dependencies.getChannelsMenuSectionNavigationUseCase,
                features: dependencies.features,
                upsellSceneFactory: dependencies.upsellSceneFactory
            )
        } else {
            let channelGuideFactory = ChannelGuideCoordinatorFactory(
                notificationCenter: dependencies.notificationCenter,
                userDetailsRepository: dependencies.userDetailsRepository,
                dataDelegate: mainNavigationHandler,
                impressionsCollectorFactory: dependencies.impressionsCollectorFactory,
                upsellSceneFactory: dependencies.upsellSceneFactory
            )
            return ChannelGuideCoordinator(
                hostViewController: hostViewController,
                factory: channelGuideFactory,
                features: dependencies.features
            )
        }
    }

    func makeDownloadsCoordinator(hostViewController: MainNavigationUpdatable) -> Coordinator {
        let downloadsFactory = DownloadsCoordinatorFactory()
        return DownloadsCoordinatorImpl(
            mainNavigationContainer: hostViewController,
            persona: dependencies.persona,
            factory: downloadsFactory,
            features: dependencies.features
        )
    }

    func makePlayerNavigationHandler(mainNavigationHandler: MainNavigationHandler, mainNavigationDelegate: MainNavigationDelegate?) -> PlayerNavigationHandling {
        let playerNavigationHandler = PlayerNavigationHandler(
            upsellSceneFactory: dependencies.upsellSceneFactory,
            pdpFactory: dependencies.pdpFactory,
            mainNavigationHandler: mainNavigationHandler,
            features: dependencies.features,
            convertLegacyChannelUseCase: Dependency.resolve((any ConvertLegacyChannelUseCase).self),
            playContextFactory: dependencies.playContextFactory
        )

        playerNavigationHandler.mainNavigationDelegate = mainNavigationDelegate

        return playerNavigationHandler
    }

    func makeMyAccountCoordinator(hostViewController: AppContainerViewControllerProtocol) -> Coordinator {
        return MyAccountCoordinator(
            hostController: hostViewController,
            myAccountFactory: Dependency.resolve(MyAccountFactory.self),
            trackingTransparency: dependencies.trackingTransparency
        )
    }
}
