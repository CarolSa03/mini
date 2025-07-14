import AccessibilityApi
import Account_Api
import ActionsMenuApi
import Analytics
import AppReportingApi
import AppSettings_Api
import AppSettings_Impl
import Browse_Api
import BrowseApi
import ChannelGuideApi
import ChannelsApi
import ChromecastUi
import Collections_Api
import Collections_Impl
import ConcurrencyApi
import Core_Accessibility_Api
import Core_AppMetrics_Api
import Core_Common_Api
import Core_Images_Api
import Core_SafeStorage_Api
import Core_Ui_Api
import CoreAppLifecycleApi
import DIManagerSwift
import EventHub
import GamesApi
import Impressions_Api
import Legacy_Api
import Localisation_Api
import MyStuff_Api
import PCLSContinueWatchingApi
import PCLSLabelsApi
import PCLSReachabilityApi
import PersonasApi
import PlayerContextApi
import PlayerSharedApi
import TimeApi
import UIKit
import UmvTokenApi
import WatchNext_Api

protocol SearchCoordinatorFactoryProtocol {
    func makeSearchViewController(navigationDelegate: MainNavigationDelegate?) -> UIViewController
    func makePDPViewController(
        with asset: Legacy_Api.Asset,
        curatorInfo: CuratorInfo?,
        parentRouter: DeeplinkRouting?,
        navigationController: UINavigationController?
    ) -> UIViewController?

    // swiftlint:disable:next function_parameter_count
    func makeCollectionGroupViewController(
        asset: Legacy_Api.Asset,
        navigationDelegate: MainNavigationDelegate,
        mainNavigationHandler: MainNavigationHandler?,
        menuAlias: String?,
        catalogueType: Legacy_Api.Asset.CatalogueType?,
        isMyStuffAvailable: Bool
    ) -> UIViewController

    // swiftlint:disable:next function_parameter_count
    func makeCollectionNavigationViewController(
        _ template: CollectionGroupRail.RenderHint.Template?,
        linkId: String?,
        linkIdRank: String?,
        nodeId: String?,
        collectionId: String?,
        title: String?,
        menuAlias: String?,
        navigationController: UINavigationController?,
        curatorAds: CollectionGroupRail.Campaign?,
        navigationDelegate: MainNavigationDelegate?,
        railIndex: Int?,
        fromViewAll: Bool
    ) -> UIViewController
}

struct SearchCoordinatorFactory {
    struct Dependencies {
        let features: Features
        let pdpFactory: PDPFactoryProtocol
        let upsellSceneFactory: UpsellSceneFactory
        let getChannelByKeyUseCase: any GetChannelByKeyUseCase
        let getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase
        let observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase
        let observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase
        let observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase
        let observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase
        let appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler
        let imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol
        let imageLoader: ImageLoader
        let persona: Persona
        let player: PlayerProtocol
        let assetActionValidator: AssetActionValidating
        let appStoreReview: AppStoreReviewManager
        let freeWheelAnd3PTracker: AssetFreeWheelAnd3PTracker
        let analytics: AnalyticsProtocol
        let reachability: Reachability
        let appMetricsManager: AppMetricsManager
        weak var mainNavigationHandler: MainNavigationHandler?
        let getSearchMenuItemUseCase: any GetSearchMenuItemUseCase
        let observeSearchAssetsUseCase: any ObserveSearchAssetsUseCase
        let addRecentSearchTermUseCase: any AddRecentSearchTermUseCase
        let getRecentSearchesUseCase: any GetRecentSearchesUseCase
        let observeSearchEmptyStateUseCase: any ObserveSearchEmptyStateUseCase
        let labels: Labels
        let tilesFactory: SearchTilesFactory
        let fetchAccessibilityLabelUseCase: any FetchAccessibilityLabelUseCase
        let fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase
        let fetchRailGridUseCase: any FetchRailGridUseCase
        let observeTilesUseCase: any ObserveBrowseTilesUseCase
        let resolveTileUseCase: any ResolveTileUseCase
        let taskRunner: ConcurrencyTaskRunner

        init(
            features: Features,
            upsellSceneFactory: UpsellSceneFactory,
            pdpFactory: PDPFactoryProtocol,
            getChannelByKeyUseCase: any GetChannelByKeyUseCase,
            getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase,
            observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase,
            observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase,
            observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase,
            observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase,
            appStartupMetrics: ApplicationStartupLaunchAppMetricsHandler,
            imageURLParametersGeneratorFactory: ImageURLParametersGeneratorFactoryProtocol,
            imageLoader: ImageLoader,
            persona: Persona,
            player: PlayerProtocol,
            mainNavigationHandler: MainNavigationHandler?,
            assetActionValidator: AssetActionValidating,
            appStoreReview: AppStoreReviewManager,
            freeWheelAnd3PTracker: AssetFreeWheelAnd3PTracker,
            reachability: Reachability,
            analytics: AnalyticsProtocol,
            appMetricsManager: AppMetricsManager,
            getSearchMenuItemUseCase: any GetSearchMenuItemUseCase,
            observeSearchAssetsUseCase: any ObserveSearchAssetsUseCase,
            addRecentSearchTermUseCase: any AddRecentSearchTermUseCase,
            getRecentSearchesUseCase: any GetRecentSearchesUseCase,
            observeSearchEmptyStateUseCase: any ObserveSearchEmptyStateUseCase,
            labels: Labels,
            tilesFactory: SearchTilesFactory,
            fetchAccessibilityLabelUseCase: any FetchAccessibilityLabelUseCase,
            fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase,
            fetchRailGridUseCase: any FetchRailGridUseCase,
            observeTilesUseCase: any ObserveBrowseTilesUseCase,
            resolveTileUseCase: any ResolveTileUseCase,
            taskRunner: ConcurrencyTaskRunner
        ) {
            self.features = features
            self.upsellSceneFactory = upsellSceneFactory
            self.pdpFactory = pdpFactory
            self.getChannelByKeyUseCase = getChannelByKeyUseCase
            self.getChannelsMenuSectionNavigationUseCase = getChannelsMenuSectionNavigationUseCase
            self.observeLocalisationTerritoryChangesUseCase = observeLocalisationTerritoryChangesUseCase
            self.observeLocalisationBouquetChangesUseCase = observeLocalisationBouquetChangesUseCase
            self.observeServerTimeOffsetChangesUseCase = observeServerTimeOffsetChangesUseCase
            self.observeUserDetailsChangesUseCase = observeUserDetailsChangesUseCase
            self.appStartupMetrics = appStartupMetrics
            self.imageURLParametersGeneratorFactory = imageURLParametersGeneratorFactory
            self.imageLoader = imageLoader
            self.persona = persona
            self.player = player
            self.mainNavigationHandler = mainNavigationHandler
            self.assetActionValidator = assetActionValidator
            self.appStoreReview = appStoreReview
            self.freeWheelAnd3PTracker = freeWheelAnd3PTracker
            self.reachability = reachability
            self.analytics = analytics
            self.appMetricsManager = appMetricsManager
            self.getSearchMenuItemUseCase = getSearchMenuItemUseCase
            self.observeSearchAssetsUseCase = observeSearchAssetsUseCase
            self.addRecentSearchTermUseCase = addRecentSearchTermUseCase
            self.getRecentSearchesUseCase = getRecentSearchesUseCase
            self.observeSearchEmptyStateUseCase = observeSearchEmptyStateUseCase
            self.labels = labels
            self.tilesFactory = tilesFactory
            self.fetchAccessibilityLabelUseCase = fetchAccessibilityLabelUseCase
            self.fetchBrowseTilesUseCase = fetchBrowseTilesUseCase
            self.fetchRailGridUseCase = fetchRailGridUseCase
            self.observeTilesUseCase = observeTilesUseCase
            self.resolveTileUseCase = resolveTileUseCase
            self.taskRunner = taskRunner
        }
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
}

extension SearchCoordinatorFactory: SearchCoordinatorFactoryProtocol {
    func makeSearchViewController(navigationDelegate: MainNavigationDelegate?) -> UIViewController {
        let imageURLParametersGenerator = dependencies.imageURLParametersGeneratorFactory.makeImageURLParametersGenerator(pageIdentifier: .search)
        let viewModel = SearchViewModel(
            getSearchMenuItemUseCase: dependencies.getSearchMenuItemUseCase,
            imageURLParametersGenerator: imageURLParametersGenerator,
            analytics: dependencies.analytics,
            labels: dependencies.labels,
            personaType: dependencies.persona.type,
            observeSearchAssetsUseCase: dependencies.observeSearchAssetsUseCase,
            addRecentSearchTermUseCase: dependencies.addRecentSearchTermUseCase,
            getRecentSearchesUseCase: dependencies.getRecentSearchesUseCase,
            observeLocalisationTerritoryChangesUseCase: dependencies.observeLocalisationTerritoryChangesUseCase,
            observeLocalisationBouquetChangesUseCase: dependencies.observeLocalisationBouquetChangesUseCase,
            observeServerTimeOffsetChangesUseCase: dependencies.observeServerTimeOffsetChangesUseCase,
            observeUserDetailsChangesUseCase: dependencies.observeUserDetailsChangesUseCase,
            observeSearchEmptyStateUseCase: dependencies.observeSearchEmptyStateUseCase,
            fetchBrowseTilesUseCase: dependencies.fetchBrowseTilesUseCase,
            fetchRailGridUseCase: dependencies.fetchRailGridUseCase,
            observeTilesUseCase: dependencies.observeTilesUseCase,
            resolveTileUseCase: dependencies.resolveTileUseCase,
            getChannelByKeyUseCase: dependencies.getChannelByKeyUseCase,
            getChannelsMenuSectionNavigationUseCase: dependencies.getChannelsMenuSectionNavigationUseCase,
            taskRunner: dependencies.taskRunner,
            actionsMenuHelper: Dependency.resolve(ActionsMenuHelper.self),
            ctaSetHelper: Dependency.resolve(CTASetHelper.self),
            ctaSpecActionResolver: Dependency.resolve(CTASpecActionResolver.self),
            myStuffService: Dependency.resolve(MyStuffService.self),
            myStuffAssetsHandler: Dependency.resolve(MyStuffAssetsHandler.self),
            notificationCenter: Dependency.resolve(NotificationCenterProtocol.self),
            uiAccessibilityWrapper: Dependency.resolve(UIAccessibilityWrapper.self),
            accessibility: Dependency.resolve(Accessibility.self),
            verifyPlayoutAccessUseCase: Dependency.resolve((any VerifyPlayoutAccessUseCase).self),
            pushNotificationManager: Dependency.resolve(PushNotificationManagerProtocol.self),
            ratingBadgeItemsFactory: Dependency.resolve(RatingBadgeItemsFactory.self),
            miniPDPTileFilter: Dependency.resolve(),
            watchlistErrorNotificationFactory: Dependency.resolve(type: ErrorNotificationProtocol.self, name: .errorNotificationName.watchlist),
            eventHub: Dependency.resolve(EventHubProtocol.self)
        )

        let searchViewController = SearchViewController(
            viewModel: viewModel,
            navigationDelegate: navigationDelegate,
            features: dependencies.features,
            labels: dependencies.labels,
            imageLoader: dependencies.imageLoader,
            tilesFactory: dependencies.tilesFactory
        )
        return searchViewController
    }

    func makePDPViewController(
        with asset: Legacy_Api.Asset,
        curatorInfo: CuratorInfo?,
        parentRouter: DeeplinkRouting?,
        navigationController: UINavigationController?
    ) -> UIViewController? {
        return dependencies.pdpFactory.makeViewController(with: asset,
                                                          curatorInfo: curatorInfo,
                                                          parentRouter: parentRouter,
                                                          navigationController: navigationController,
                                                          mainNavigationHandler: dependencies.mainNavigationHandler,
                                                          player: dependencies.player,
                                                          onMyStuffUpdated: nil)
    }

    // swiftlint:disable:next function_parameter_count
    func makeCollectionGroupViewController(
        asset: Legacy_Api.Asset,
        navigationDelegate: MainNavigationDelegate,
        mainNavigationHandler: MainNavigationHandler?,
        menuAlias: String?,
        catalogueType: Legacy_Api.Asset.CatalogueType?,
        isMyStuffAvailable: Bool
    ) -> UIViewController {
        return makeCollectionGroupViewController(
            railAttributes: nil,
            nodeId: asset.nodeId,
            browseSection: nil,
            navigationDelegate: navigationDelegate,
            isKidsProfile: false,
            isCollectionGroup: true,
            collectionGroupHomeTitle: asset.title,
            isMyStuffAvailable: isMyStuffAvailable,
            menuAlias: menuAlias,
            catalogueType: catalogueType
        )
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    private func makeCollectionGroupViewController(
        railAttributes: CollectionGroupRail.Attributes?,
        nodeId: String?,
        browseSection: BrowseSection?,
        navigationDelegate: MainNavigationDelegate?,
        isKidsProfile: Bool,
        isCollectionGroup: Bool,
        collectionGroupHomeTitle: String?,
        isMyStuffAvailable: Bool,
        menuAlias: String?,
        catalogueType: Legacy_Api.Asset.CatalogueType?
    ) -> UIViewController {
        let railDetails = LazyLoadingCollectionGroupViewModel.RailDetails(browseSection: browseSection, railAttributes: railAttributes, nodeId: nodeId)
        let viewModel = LazyLoadingCollectionGroupViewModel(
            dependencies: .init(
                concurrencyTaskRunner: Dependency.resolve(ConcurrencyTaskRunner.self),
                umvTokenRefresher: Dependency.resolve(UmvTokenRefresher.self),
                assetActionValidator: dependencies.assetActionValidator,
                appReviewManager: dependencies.appStoreReview,
                freeWheelAnd3PTracker: dependencies.freeWheelAnd3PTracker,
                analytics: dependencies.analytics,
                features: dependencies.features,
                reachability: dependencies.reachability,
                railDetails: railDetails,
                isKidsProfile: isKidsProfile,
                isMyStuffAvailable: isMyStuffAvailable,
                observePageUseCase: Dependency.resolve((any ObserveBrowsePageUseCase).self),
                observeBrowseTilesUseCase: Dependency.resolve((any ObserveBrowseTilesUseCase).self),
                observeTilesUseCase: Dependency.resolve(),
                observePageTilesWarmupUseCase: Dependency.resolve((any ObservePageTilesWarmupUseCase).self),
                observeLocalisationTerritoryChangesUseCase: dependencies.observeLocalisationTerritoryChangesUseCase,
                observeLocalisationBouquetChangesUseCase: dependencies.observeLocalisationBouquetChangesUseCase,
                observeServerTimeOffsetChangesUseCase: dependencies.observeServerTimeOffsetChangesUseCase,
                observeUserDetailsChangesUseCase: dependencies.observeUserDetailsChangesUseCase,
                getChannelsMenuSectionNavigationUseCase: Dependency.resolve((any GetChannelsMenuSectionNavigationUseCase).self),
                fetchTilesUseCase: Dependency.resolve((any FetchBrowseTilesUseCase).self),
                resolveTileUseCase: Dependency.resolve((any ResolveTileUseCase).self),
                checkAccountSegmentNoAdsUseCase: Dependency.resolve((any CheckAccountSegmentNoAdsUseCase).self),
                navigationDelegate: navigationDelegate,
                menuAlias: menuAlias,
                catalogueType: catalogueType,
                appStartupMetrics: dependencies.appStartupMetrics,
                curatorInfoFactory: Dependency.resolve(CuratorInfoFactory.self),
                reportManager: Dependency.resolve(ReportManager.self),
                browseErrorReporter: Dependency.resolve(BrowseErrorReporter.self),
                labels: Dependency.resolve(Labels.self),
                myStuffService: Dependency.resolve(MyStuffService.self),
                myStuffAssetsHandler: Dependency.resolve(MyStuffAssetsHandler.self),
                actionSheetPlaybackAssetHandler: Dependency.resolve(ActionSheetPlaybackAssetHandler.self),
                configs: Dependency.resolve(Configs.self),
                accessibility: Dependency.resolve(Accessibility.self),
                impressionsCollectorFactory: Dependency.resolve(ImpressionsCollectorFactory.self),
                imageLoader: Dependency.resolve(ImageLoader.self),
                actionsMenuHelper: Dependency.resolve(ActionsMenuHelper.self),
                viewAllNodeId: nil,
                originTemplate: nil,
                ignoreBrowseTilesUseCase: Dependency.resolve((any IgnoreBrowseTilesUseCase).self),
                ctaSpecActionResolver: Dependency.resolve((any CTASpecActionResolver).self),
                notificationCenter: Dependency.resolve(NotificationCenterProtocol.self),
                uiAccessibilityWrapper: Dependency.resolve(UIAccessibilityWrapper.self),
                fetchSingleLiveEventToLegacyUseCase: Dependency.resolve((any FetchSingleLiveEventToLegacyUseCase).self),
                observeMyStuffAssetIDsRailUseCase: Dependency.resolve((any ObserveMyStuffAssetIDsRailUseCase).self),
                browseDataTypeAppMetricsHandler: Dependency.resolve((any BrowseDataTypeAppMetricsHandler).self),
                ctaSetHelper: Dependency.resolve(CTASetHelper.self),
                setCachedBrowseDirtyAsyncUseCase: Dependency.resolve((any SetCachedBrowseDirtyAsyncUseCase).self),
                removeTileFromRailUseCase: Dependency.resolve((any RemoveTileFromRailUseCase).self),
                removeFromContinueWatchingUseCase: Dependency.resolve((any RemoveFromContinueWatchingUseCase).self),
                tileImageryProvider: nil,
                bootstrapBackgroundWorker: Dependency.resolve(BootstrapBackgroundWorker.self),
                verifyPlayoutAccessUseCase: Dependency.resolve((any VerifyPlayoutAccessUseCase).self),
                getGameWebViewConfigUseCase: Dependency.resolve((any GetGameWebViewConfigUseCase).self),
                pushNotificationManager: Dependency.resolve(PushNotificationManagerProtocol.self),
                miniPDPTileFilter: Dependency.resolve(),
                miniPlayersController: Dependency.resolve(),
                observeSportsMetadataUseCase: Dependency.resolve((any ObserveSportsMetadataUseCase).self),
                startPollingSportsMetadataUseCase: Dependency.resolve((any StartPollingSportsMetadataUseCase).self),
                stopPollingSportsMetadataUseCase: Dependency.resolve((any StopPollingSportsMetadataUseCase).self),
                getLiveDetailsUseCase: Dependency.resolve((any GetLiveDetailsUseCase).self),
                liveMetadataCache: Dependency.resolve((any LiveMetadataCache).self),
                ratingBadgeItemsFactory: Dependency.resolve(RatingBadgeItemsFactory.self),
                eventHub: Dependency.resolve(EventHubProtocol.self),
                appLifecycleMonitor: Dependency.resolve(AppLifecycleMonitor.self),
                fastRefreshHandler: Dependency.resolve((any FastRefreshHandler).self, args: nodeId),
                watchlistErrorNotificationFactory: Dependency.resolve(type: ErrorNotificationProtocol.self, name: .errorNotificationName.watchlist),
                continueWatchingErrorNotificationFactory: Dependency.resolve(type: ErrorNotificationProtocol.self, name: .errorNotificationName.continueWatching),
                liveMetadataManagerFactory: Dependency.resolve()
            )
        )
        let viewController = LazyLoadingCollectionGroupViewController(
            viewModel: viewModel,
            homeTitle: collectionGroupHomeTitle,
            userInteractionEvaluator: UserInteractionEvaluator(),
            notificationCenter: Dependency.resolve(NotificationCenterProtocol.self),
            reachability: dependencies.reachability,
            affiliateChannelsLocHndlr: AffiliateChannelsLocationHandlerImpl(
                isKidsProfile: isKidsProfile,
                restartServicesUseCase: Dependency.resolve((any RestartServicesUseCase).self),
                taskRunner: Dependency.resolve(ConcurrencyTaskRunner.self)
            ),
            features: dependencies.features,
            labels: Dependency.resolve(Labels.self),
            configs: Dependency.resolve(Configs.self),
            mainQueue: DispatchQueue.main,
            impressionsCollectorFactory: Dependency.resolve(ImpressionsCollectorFactory.self),
            chromecastButtonProvider: Dependency.resolve(Provider<ChromecastButton>.self),
            animatorController: nil,
            playContextFactory: Dependency.resolve(PlayContextFactory.self),
            fetchAccessibilityLabelUseCase: dependencies.fetchAccessibilityLabelUseCase,
            imageLoader: dependencies.imageLoader,
            shouldPlayWifiOnlyUseCase: Dependency.resolve((any ShouldPlayWifiOnlyUseCase).self),
            uiAuditorManagerFactory: Dependency.resolve(
                (any UIAuditorManagerFactoryV1).self,
                args: AppErrorDomain.search(path: nodeId).asAnyErrorDomain()
            ),
            mainTabBarHeightFromBottom: nil
        )

        return viewController
    }

    // swiftlint:disable:next function_parameter_count
    func makeCollectionNavigationViewController(
        _ template: CollectionGroupRail.RenderHint.Template?,
        linkId: String?,
        linkIdRank: String?,
        nodeId: String?,
        collectionId: String?,
        title: String?,
        menuAlias: String?,
        navigationController: UINavigationController?,
        curatorAds: CollectionGroupRail.Campaign?,
        navigationDelegate: MainNavigationDelegate?,
        railIndex: Int?,
        fromViewAll: Bool
    ) -> UIViewController {
        let imageURLParametersGenerator = dependencies.imageURLParametersGeneratorFactory.makeImageURLParametersGenerator(pageIdentifier: .collections)
        return CollectionGridFactory.makeGridViewControllerWithCoordinator(
            navigationController: navigationController,
            navigationDelegate: navigationDelegate,
            collectionId: collectionId,
            linkId: linkId,
            linkIdRank: linkIdRank,
            nodeId: nodeId,
            template: template,
            menuAlias: menuAlias,
            title: title,
            curatorAds: curatorAds,
            player: dependencies.player,
            pdpFactory: dependencies.pdpFactory,
            curatorInfoFactory: Dependency.resolve(CuratorInfoFactory.self),
            upsellFactory: dependencies.upsellSceneFactory,
            imageURLParametersGenerator: imageURLParametersGenerator,
            features: dependencies.features,
            appMetricsManager: dependencies.appMetricsManager,
            railIndex: railIndex,
            fromViewAll: fromViewAll,
            isKidsProfile: dependencies.persona.type == .kid,
            viewAllSelectedNodeId: nil,
            viewAllNodeId: nil,
            originTemplate: nil
        )
    }
}

// swiftlint:disable:this file_length
