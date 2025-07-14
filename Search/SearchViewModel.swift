// swiftlint:disable file_length
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
import Combine
import CombineSchedulers
import ConcurrencyApi
import Core_Accessibility_Api
import Core_Common_Api
import Core_Ui_Api
import EventHub
import Foundation
import GSTCoreServicesOVPApi
import Legacy_Api
import Localisation_Api
import MiniPDPAPI
import MyStuff_Api
import PCLSBrowseChannelsCoreApi
import PCLSLabelsApi
import PersonasApi
import PlayerSharedApi
import SearchApi
import TilesKitApi
import TimeApi
import UIKit
import UmvTokenApi

protocol SearchViewModelProtocol {
    var noSearchResults: Bool { get }
    var outputEvents: SearchViewModel.OutputEvents { get set }
    var personaType: Persona.PersonaType { get }
    var tilesDidChange: AnyPublisher<TileUpdates<String>, Never> { get }

    func setup()
    func fetchPlaceholderCollection(contentFormat: SearchContentFormat, forceUpdate: Bool)
    func shouldFetchNoResultsPlaceholderCollection(searchTab: SearchTab) -> Bool
    func didSelectTab(for term: String?, contentFormat: SearchContentFormat, type: SearchType)
    func search(for term: String?, contentFormat: SearchContentFormat, type: SearchType)
    @MainActor func didSelect(tile: TileViewModel, index: Int)
    func trackOpen()
    func trackExit()
    func trackExceededMaturityRating(for asset: Legacy_Api.Asset?)
    func trackCancel(term: String?, areResultsVisible: Bool)
    func shouldHideTabs() -> Bool
    func switchTab(to contentFormat: SearchContentFormat)
    func getRecentSearches() -> [String]
    func getImageURLQueryParameters(forIndex index: Int) -> [String: String]
    @MainActor func resolve(tileId: String, contentFormat: SearchContentFormat) -> TileViewModel
    func fetch(tiles tileIds: [String])
    func cancelFetchingIfPossible(tiles tileIds: [String])
    func handleAppearance()
    func handleDisappearance()
    func createAssetMetadataItems(
        with asset: Asset,
        options: ActionsMenuApi.AssetMetadataOptionSet,
        maxCharacters: Int
    ) -> [ActionsMenuApi.MetadataItem]
}

final class SearchViewModel: SearchViewModelProtocol { // swiftlint:disable:this type_body_length
    struct OutputEvents {
        var displayFullScreenLoading: ((Bool) -> Void)?
        var presentEmptySearch: ((_ resultsTab: SearchTab, _ contentFormat: SearchContentFormat, _ shouldRefresh: Bool) -> Void)?
        var presentResults: ((_ results: SearchResults, _ contentFormat: SearchContentFormat) -> Void)?
        var presentNoResultsPlaceholder: ((_ resultsTab: SearchTab, _ contentFormat: SearchContentFormat) -> Void)?
        var presentFailedResults: (() -> Void)?
        var presentInputEnded: (() -> Void)?
        var routeToPlayer: ((_ asset: Legacy_Api.Asset) -> Void)?
        var routeToPdp: ((_ asset: Legacy_Api.Asset) -> Void)?
        var routeToMiniPdp: ((
            _ railId: String,
            _ tileId: String,
            _ ctaSetHandler: CTASetHandler,
            _ analyticsDataSource: MiniPDPAnalyticsDataSource
        ) -> Void)?
        var routeToGrid: ((_ asset: Legacy_Api.Asset) -> Void)?
        var routeToCollection: ((_ asset: Legacy_Api.Asset) -> Void)?
        var routeToUpsellJourney: ((_ asset: Legacy_Api.Asset, _ contentSegments: UpsellContentSegments) -> Void)?
        var routeToChannel: ((_ liveProgram: WatchLiveProgramModel?) -> Void)?
        var numberOfItemsPerRow: (() -> Int?)?
        var presentActionSheet: ((SheetOptions) -> Void)?
        var dismissActionSheet: ((_ completion: @escaping () -> Void) -> Void)?
        var animateMyStuffCTA: ((Bool, IndexPath) -> Void)?
    }

    private(set) var noSearchResults = false
    var outputEvents: OutputEvents = OutputEvents()
    var personaType: Persona.PersonaType
    var lastSearchTerm: String?
    var lastContentFormat: SearchContentFormat = .longform

    private var popularSearchRail: Rail?
    private var searchAssetsSubscription: AnyCancellable?
    private var searchEmptySubscription: AnyCancellable?
    private var contextChangesSubscription: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private let imageURLParametersGenerator: ImageURLParametersGenerating
    private let getSearchMenuItemUseCase: any GetSearchMenuItemUseCase
    private let assetActionValidator: AssetActionValidating
    private var assetMetadata: Analytics.AssetMetadata?
    private let umvTokenRefresher: UmvTokenRefresher
    private let observeSearchAssetsUseCase: any ObserveSearchAssetsUseCase
    private let addRecentSearchTermUseCase: any AddRecentSearchTermUseCase
    private let getRecentSearchesUseCase: any GetRecentSearchesUseCase
    private let observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase
    private let observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase
    private let observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase
    private let observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase
    private let observeSearchEmptyStateUseCase: any ObserveSearchEmptyStateUseCase
    private let fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase
    private let fetchRailGridUseCase: any FetchRailGridUseCase
    private let observeTilesUseCase: any ObserveBrowseTilesUseCase
    private let taskRunner: ConcurrencyTaskRunner
    private let contextChangesScheduler: AnySchedulerOf<DispatchQueue>
    private let reporter: ReportManager
    private var getChannelByKeyUseCase: any GetChannelByKeyUseCase
    private let getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase
    private let verifyPlayoutAccessUseCase: any VerifyPlayoutAccessUseCase
    private var pushNotificationManager: any PushNotificationManagerProtocol
    private let ratingBadgeItemsFactory: RatingBadgeItemsFactory
    private let miniPDPTileFilter: any MiniPDPTileFilterV1

    let myStuffService: MyStuffService
    let mainQueue: DispatchMainQueueable
    let uiAccessibilityWrapper: any UIAccessibilityWrapper
    let accessibility: Accessibility
    let labels: Labels
    let notificationCenter: NotificationCenterProtocol
    let actionsMenuHelper: ActionsMenuHelper
    let ctaSpecActionResolver: CTASpecActionResolver
    let myStuffAssetsHandler: MyStuffAssetsHandler
    let searchTabs: SearchTabLogic
    let analytics: AnalyticsProtocol
    let features: Features
    let resolveTileUseCase: any ResolveTileUseCase
    let ctaSetHelper: CTASetHelper
    let watchlistErrorNotificationFactory: ErrorNotificationProtocol
    let eventHub: EventHubProtocol

    // MARK: Initilisation

    init(
        searchTabs: SearchTabLogic = SearchTabInteractor(),
        getSearchMenuItemUseCase: any GetSearchMenuItemUseCase,
        imageURLParametersGenerator: ImageURLParametersGenerating,
        analytics: AnalyticsProtocol = Dependency.resolve(AnalyticsProtocol.self),
        features: Features = Dependency.resolve(Features.self),
        labels: Labels,
        assetActionValidator: AssetActionValidating = Dependency.resolve(AssetActionValidating.self),
        umvTokenRefresher: UmvTokenRefresher = Dependency.resolve(UmvTokenRefresher.self),
        mainQueue: DispatchMainQueueable = DispatchQueue.main,
        personaType: Persona.PersonaType = .adult,
        observeSearchAssetsUseCase: any ObserveSearchAssetsUseCase,
        addRecentSearchTermUseCase: any AddRecentSearchTermUseCase,
        getRecentSearchesUseCase: any GetRecentSearchesUseCase,
        observeLocalisationTerritoryChangesUseCase: any ObserveLocalisationTerritoryChangesUseCase,
        observeLocalisationBouquetChangesUseCase: any ObserveLocalisationBouquetChangesUseCase,
        observeServerTimeOffsetChangesUseCase: any ObserveServerTimeOffsetChangesUseCase,
        observeUserDetailsChangesUseCase: any ObserveUserDetailsChangesUseCase,
        observeSearchEmptyStateUseCase: any ObserveSearchEmptyStateUseCase,
        fetchBrowseTilesUseCase: any FetchBrowseTilesUseCase,
        fetchRailGridUseCase: any FetchRailGridUseCase,
        observeTilesUseCase: any ObserveBrowseTilesUseCase,
        resolveTileUseCase: any ResolveTileUseCase,
        getChannelByKeyUseCase: any GetChannelByKeyUseCase,
        getChannelsMenuSectionNavigationUseCase: any GetChannelsMenuSectionNavigationUseCase,
        taskRunner: ConcurrencyTaskRunner,
        contextChangesScheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.global(qos: .default).eraseToAnyScheduler(),
        reporter: ReportManager = Dependency.resolve(ReportManager.self),
        actionsMenuHelper: ActionsMenuHelper,
        ctaSetHelper: CTASetHelper,
        ctaSpecActionResolver: CTASpecActionResolver,
        myStuffService: MyStuffService,
        myStuffAssetsHandler: MyStuffAssetsHandler,
        notificationCenter: NotificationCenterProtocol,
        uiAccessibilityWrapper: any UIAccessibilityWrapper,
        accessibility: Accessibility,
        verifyPlayoutAccessUseCase: any VerifyPlayoutAccessUseCase,
        pushNotificationManager: any PushNotificationManagerProtocol,
        ratingBadgeItemsFactory: RatingBadgeItemsFactory,
        miniPDPTileFilter: any MiniPDPTileFilterV1,
        watchlistErrorNotificationFactory: ErrorNotificationProtocol,
        eventHub: EventHubProtocol
    ) {
        self.imageURLParametersGenerator = imageURLParametersGenerator
        self.getSearchMenuItemUseCase = getSearchMenuItemUseCase
        self.analytics = analytics
        self.features = features
        self.labels = labels
        self.assetActionValidator = assetActionValidator
        self.umvTokenRefresher = umvTokenRefresher
        self.searchTabs = searchTabs
        self.mainQueue = mainQueue
        self.personaType = personaType
        self.observeSearchAssetsUseCase = observeSearchAssetsUseCase
        self.addRecentSearchTermUseCase = addRecentSearchTermUseCase
        self.getRecentSearchesUseCase = getRecentSearchesUseCase
        self.observeLocalisationTerritoryChangesUseCase = observeLocalisationTerritoryChangesUseCase
        self.observeLocalisationBouquetChangesUseCase = observeLocalisationBouquetChangesUseCase
        self.observeServerTimeOffsetChangesUseCase = observeServerTimeOffsetChangesUseCase
        self.observeUserDetailsChangesUseCase = observeUserDetailsChangesUseCase
        self.observeSearchEmptyStateUseCase = observeSearchEmptyStateUseCase
        self.fetchBrowseTilesUseCase = fetchBrowseTilesUseCase
        self.fetchRailGridUseCase = fetchRailGridUseCase
        self.observeTilesUseCase = observeTilesUseCase
        self.resolveTileUseCase = resolveTileUseCase
        self.getChannelByKeyUseCase = getChannelByKeyUseCase
        self.getChannelsMenuSectionNavigationUseCase = getChannelsMenuSectionNavigationUseCase
        self.taskRunner = taskRunner
        self.contextChangesScheduler = contextChangesScheduler
        self.reporter = reporter
        self.actionsMenuHelper = actionsMenuHelper
        self.ctaSetHelper = ctaSetHelper
        self.ctaSpecActionResolver = ctaSpecActionResolver
        self.myStuffService = myStuffService
        self.myStuffAssetsHandler = myStuffAssetsHandler
        self.notificationCenter = notificationCenter
        self.uiAccessibilityWrapper = uiAccessibilityWrapper
        self.accessibility = accessibility
        self.verifyPlayoutAccessUseCase = verifyPlayoutAccessUseCase
        self.pushNotificationManager = pushNotificationManager
        self.ratingBadgeItemsFactory = ratingBadgeItemsFactory
        self.miniPDPTileFilter = miniPDPTileFilter
        self.watchlistErrorNotificationFactory = watchlistErrorNotificationFactory
        self.eventHub = eventHub
        umvTokenRefresher.addListener(self)
    }

    func setup() {
        observeContextChanges()

        let searchResults: SearchResults = SearchResults(
            tabs: searchTabs.getResults()
        )
        outputEvents.presentResults?(searchResults, lastContentFormat)
    }

    func handleAppearance() {
        pushNotificationManager.observer = self
    }

    func handleDisappearance() {
        pushNotificationManager.observer = nil
    }

    private func observeSearchResults(
        searchTerm: String,
        contentFormat: SearchContentFormat
    ) {
        searchAssetsSubscription?.cancel()

        let input: ObserveSearchAssetsUseCaseInput = ObserveSearchAssetsUseCaseInput(
            term: searchTerm,
            contentFormat: contentFormat
        )

        searchAssetsSubscription = observeSearchAssetsUseCase.execute(input: input)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard case .failure(let error) = completion else { return }
                    self?.noSearchResults = false
                    self?.handleSearchResults(.failure(error))
                },
                receiveValue: { [weak self] data in
                    self?.noSearchResults = false
                    self?.handleSearchResults(.success(data))
                }
            )
    }

    func shouldFetchNoResultsPlaceholderCollection(searchTab: SearchTab) -> Bool {
        let hasNoResults = searchTab.searchNoResultsReason == .noMatch && searchTab.items.isEmpty

        defer {
            if
                hasNoResults,
                !features.isEnabled(.searchNoResultsContent)
            {
                noSearchResults = true

                outputEvents.presentEmptySearch?(
                    searchTab,
                    searchTab.contentFormat,
                    true
                )
            }
        }

        guard
            hasNoResults,
            personaType != .kid
        else {
            return false
        }

        return features.isEnabled(.searchNoResultsContent)
    }

    func fetchPlaceholderCollection(
        contentFormat: SearchContentFormat,
        forceUpdate: Bool
    ) {
        guard personaType != .kid else { return }

        self.noSearchResults = contentFormat != .emptySearch

        if
            let cachedResults = fetchCachedPlaceholderCollection(contentFormat: contentFormat),
            !forceUpdate
        {
            self.mainQueue.async {
                switch contentFormat {
                case .emptySearch:
                    self.outputEvents.presentEmptySearch?(
                        cachedResults,
                        contentFormat,
                        forceUpdate
                    )
                case .longform, .clip:
                    self.outputEvents.presentNoResultsPlaceholder?(
                        cachedResults,
                        contentFormat
                    )
                }
            }
            return
        }

        guard let nodeId = fetchNodeIdForPlaceholderCollection(contentFormat: contentFormat) else { return }

        fetchRemoteEmptySearch(
            nodeId: nodeId,
            contentFormat: contentFormat,
            forceUpdate: forceUpdate
        )
    }

    private func fetchCachedPlaceholderCollection(contentFormat: SearchContentFormat) -> SearchTab? {
        switch contentFormat {
        case .longform:
            return searchTabs.isNoResultsLongformRailCached
            ? searchTabs.getSearchNoResultsTab(for: contentFormat)
            : nil
        case .clip:
            return searchTabs.isNoResultsClipRailCached
            ? searchTabs.getSearchNoResultsTab(for: contentFormat)
            : nil
        case .emptySearch:
            return searchTabs.isEmptySearchRailCached
            ? searchTabs.getSearchNoResultsTab(for: contentFormat)
            : nil
        }
    }

    private func fetchNodeIdForPlaceholderCollection(contentFormat: SearchContentFormat) -> String? {
        switch contentFormat {
        case .longform:
            return getSearchMenuItemUseCase.execute(input: .noResults)
        case .clip:
            return getSearchMenuItemUseCase.execute(input: .noClips)
        case .emptySearch:
            return getSearchMenuItemUseCase.execute(input: .emptyState)
        }
    }

    private func fetchRemoteEmptySearch(
        nodeId: String,
        contentFormat: SearchContentFormat,
        forceUpdate: Bool
    ) {
        searchEmptySubscription?.cancel()

        if
            features.isEnabled(.personalizedSearchResultsContent) ||
            features.isEnabled(.searchPortraitTileRatio)
        {
            searchEmptyStateUsingBrowseEndpoint(
                contentFormat: contentFormat,
                nodeId: nodeId
            )
        } else {
            searchEmptyState(
                contentFormat: contentFormat,
                nodeId: nodeId,
                forceUpdate: forceUpdate
            )
        }
    }

    private func searchEmptyStateUsingBrowseEndpoint(
        contentFormat: SearchContentFormat,
        nodeId: String
    ) {
        let input = FetchRailGridUseCaseInput.search(
            nodeId: nodeId,
            linkId: nil
        )

        taskRunner.run { [weak self] in
            guard let self else { return }

            let result = await fetchRailGridUseCase.execute(input: input)

            mainQueue.async { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let rail):
                    updateEmptySearch(
                        with: createCollectionGroupRail(from: rail),
                        contentFormat: contentFormat,
                        forceUpdate: true,
                        renderHint: .init(contextMenuCtaSet: rail.renderHint?.contextMenuCtaSet)
                    )
                case .failure(let error):
                    reporter.reportError(
                        domain: AppErrorDomain.search(),
                        message: error.errorMessage,
                        severity: .error,
                        dependency: .clip
                    )
                }
            }
        }
    }

    private func searchEmptyState(
        contentFormat: SearchContentFormat,
        nodeId: String,
        forceUpdate: Bool
    ) {
        let input: ObserveSearchEmptyStateUseCaseInput = ObserveSearchEmptyStateUseCaseInput(
            nodeId: nodeId,
            forceUpdate: forceUpdate
        )

        searchEmptySubscription = observeSearchEmptyStateUseCase.execute(input: input)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.mainQueue.async {
                        guard case .failure(_) = completion else { return }
                        let noResultsSearchTab = self.searchTabs.getSearchNoResultsTab(for: contentFormat)

                        if contentFormat == .longform || contentFormat == .clip {
                            self.outputEvents.presentNoResultsPlaceholder?(
                                noResultsSearchTab,
                                contentFormat
                            )
                        }
                    }
                },
                receiveValue: { [weak self] rail in
                    guard let self else { return }
                    updateEmptySearch(
                        with: rail,
                        contentFormat: contentFormat,
                        forceUpdate: input.forceUpdate,
                        renderHint: nil
                    )
                }
            )
    }

    func search(
        for term: String?,
        contentFormat: SearchContentFormat,
        type: SearchType
    ) {
        guard
            let searchTerm = term?.trim(),
            !searchTerm.isEmpty
        else {
            resetSearch()
            return
        }

        lastSearchTerm = searchTerm
        lastContentFormat = contentFormat
        switchTab(to: contentFormat)

        guard type != .button else {
            didTapSearchButton(searchTerm: searchTerm)
            return
        }

        let tab = searchTabs.getSearchTab(for: contentFormat)

        if tab.searchTerm != searchTerm {
            resetResults()
        }

        observeSearchResults(
            searchTerm: searchTerm,
            contentFormat: contentFormat
        )

        let searchResults: SearchResults = SearchResults(
            tabs: searchTabs.getResults()
        )

        outputEvents.presentResults?(
            searchResults,
            contentFormat
        )
    }

    func switchTab(to contentFormat: SearchContentFormat) {
        let previousTab = searchTabs.getSelectedTab()
        searchTabs.switchTab(to: contentFormat)

        if contentFormat == .emptySearch && contentFormat != previousTab {
            trackDidSwitchSearchTab()
        }
    }

    func didSelectTab(
        for term: String?,
        contentFormat: SearchContentFormat,
        type: SearchType
    ) {
        switchTab(to: contentFormat)
        guard contentFormat != .emptySearch else { return }

        if lastSearchTerm != term || lastContentFormat != contentFormat {
            search(
                for: term,
                contentFormat: contentFormat,
                type: type
            )
        }
    }

    private func resetResults() {
        noSearchResults = false
        searchTabs.resetTabs()
    }

    func getRecentSearches() -> [String] {
        return getRecentSearchesUseCase.execute()
    }

    private func resetSearch() {
        resetResults()

        let searchResults: SearchResults = SearchResults(
            tabs: []
        )

        outputEvents.presentResults?(
            searchResults,
            lastContentFormat
        )
    }

    private func handleSearchResults(_ result: Result<SearchServiceResults, ReportError>) {
        switch result {
        case let .success(searchResult):
            let searchTerm = searchResult.term

            guard searchTerm == self.lastSearchTerm else { return }

            self.searchTabs.buildResults(with: searchResult)

            let selectedTab = self.searchTabs.getSelectedTab()
            let results = self.searchTabs.getResults()

            if !searchTerm.isNilOrEmpty {
                self.trackSearchResults(
                    selectedTab: selectedTab,
                    results: results,
                    searchTerm: searchTerm
                )
            }

            self.mainQueue.async { [weak self] in
                self?.outputEvents.presentResults?(
                    SearchResults(tabs: results),
                    selectedTab
                )
            }

        case .failure(let error):
            handleSearchFailure(error)
        }
    }

    private func handleSearchFailure(_ error: ReportError) {
        self.mainQueue.async { [weak self] in
            guard let self else { return }

            self.reporter.reportError(
                domain: AppErrorDomain.search(),
                message: error.errorMessage,
                severity: .error,
                dependency: .clip
            )

            let searchResult = SearchServiceResults(
                term: self.lastSearchTerm ?? "",
                isSearching: false,
                searchResults: SearchServiceResults.SearchItems(
                    tiles: [],
                    format: self.lastContentFormat
                ),
                clipsResults: SearchServiceResults.SearchItems(
                    tiles: [],
                    format: self.lastContentFormat
                )
            )

            self.searchTabs.buildResults(with: searchResult)

            let searchResults = SearchResults(
                tabs: self.searchTabs.getResults()
            )

            let currentTab = self.searchTabs.getSelectedTab()

            self.outputEvents.presentResults?(
                searchResults,
                currentTab
            )

            self.outputEvents.presentFailedResults?()
        }
    }

    private func createCollectionGroupRail(from rail: Rail) -> CollectionGroupRail {
        popularSearchRail = rail

         let title = switch rail.railInfo {
         case .catalogueLink(let catalogueLink):
             catalogueLink.title
         case .collection(let collection):
             collection.title
         }

         let assets = rail.railInfo.tiles.map { tileId in
             let asset = Asset()
             asset.identifier = tileId
             asset.type = .asset
             return asset
         }

         return CollectionGroupRail(
             items: assets,
             attributes: CollectionGroupRail.Attributes(title: title ?? "")
         )
     }

    private func updateEmptySearch(
        with rail: CollectionGroupRail,
        contentFormat: SearchContentFormat,
        forceUpdate: Bool,
        renderHint: SearchRenderHint?
    ) {
        self.mainQueue.async {
            switch contentFormat {
            case .emptySearch:
                self.searchTabs.buildEmptySearchResults(with: rail, renderHint: renderHint)

                self.outputEvents.presentEmptySearch?(
                    self.searchTabs.getSearchNoResultsTab(for: contentFormat),
                    .emptySearch,
                    forceUpdate
                )
            case .longform:
                self.searchTabs.buildNoLongFormResultsAssets(with: rail)
            case .clip:
                self.searchTabs.buildNoClipResultsAssets(with: rail)
            }

            self.outputEvents.presentNoResultsPlaceholder?(
                self.searchTabs.getSearchNoResultsTab(for: contentFormat),
                contentFormat
            )
        }
    }

    private func refreshEntitlements(_ asset: Legacy_Api.Asset) {
        outputEvents.displayFullScreenLoading?(true)

        taskRunner.run { [weak self] in
            guard let self else { return }
            let result = await verifyPlayoutAccessUseCase.execute(input: asset.contentSegments ?? [])
            let hasPlayoutAccess = (try? result.get()) == true

            mainQueue.async { [weak self] in
                guard let self else { return }

                outputEvents.displayFullScreenLoading?(false)

                if hasPlayoutAccess {
                    outputEvents.routeToPlayer?(asset)
                } else {
                    routeToUpsell(asset: asset)
                }
            }
        }
    }

    func shouldHideTabs() -> Bool {
        if case .emptySearch = self.searchTabs.getSelectedTab() {
            return false
        }
        return personaType == .kid || searchTabs.getResults().count < SearchConstants.minTabsToShowBar
    }

    @MainActor func resolve(
        tileId: String,
        contentFormat: SearchContentFormat
    ) -> TileViewModel {
        var searchTab = searchTabs.getSearchTab(for: contentFormat)

        if
            searchTab.items.isEmpty,
            contentFormat != .emptySearch
        {
            searchTab = searchTabs.getSearchTab(for: .emptySearch)
        }

        let tile = searchTab
            .items
            .first(where: { $0.id == tileId })

        if tile?.asset.type == .asset {
            let output = resolveTileUseCase.execute(
                input: ResolveTileUseCaseInput(
                    tileId: tileId,
                    railId: popularSearchRail?.railId
                )
            )

            let searchTile = SearchTile(
                id: output.id,
                asset: output.asset,
                ctaSets: output.tile?.tileOverlay.ctaSets
            )

            return createTileViewModel(
                searchTile,
                tileId: output.id,
                renderHint: searchTab.renderHint,
                isPlaceholder: output.isPlaceholder
            )
        } else {
            return createTileViewModel(
                tile,
                tileId: tileId,
                renderHint: searchTab.renderHint,
                isPlaceholder: false
            )
        }
    }

    func fetch(tiles tileIds: [String]) {
        _ = fetchBrowseTilesUseCase.execute(
            input: .fetch(
                ids: tileIds,
                returnValidCache: true
            )
        )
    }

    func cancelFetchingIfPossible(tiles tileIds: [String]) {
        _ = fetchBrowseTilesUseCase.execute(
            input: .cancel(
                ids: tileIds,
                returnValidCache: true
            )
        )
    }

    // swiftlint:disable:next function_body_length
    @MainActor private func createTileViewModel(
        _ tile: SearchTile?,
        tileId: String,
        renderHint: SearchRenderHint?,
        isPlaceholder: Bool
    ) -> TileViewModel {

        let asset = tile?.asset ?? Asset()

        var tileVM = TileViewModel(
            id: tileId,
            asset: asset,
            tile: nil,
            searchTile: tile,
            channel: getChannelByKeyUseCase.execute(
                input: GetChannelByKeyUseCaseInput(
                    key: tile?.asset.serviceKey ?? "",
                    channelSection: getChannelsMenuSectionNavigationUseCase.execute()
                )
            ),
            legacyRailRenderHint: nil,
            type: typeSearch(asset: asset, isPlaceholder: isPlaceholder),
            isDirty: false,
            isUndefinedTile: false,
            shouldConfigureRating: false,
            pageRenderHint: nil,
            railRenderHint: .init(
                orientation: nil,
                template: .unrecognized,
                groupTemplate: nil,
                imageTemplate: nil,
                viewAll: nil,
                hideTitle: nil,
                hideLogo: nil,
                sort: nil,
                autoplay: nil,
                showIfKidsProfile: nil,
                interaction: nil,
                secondaryNavigation: nil,
                style: nil,
                title: nil,
                eyebrow: nil,
                tileMetadataArea: nil,
                numberedRail: nil,
                ctaSet: renderHint?.contextMenuCtaSet,
                contextMenuCtaSet: renderHint?.contextMenuCtaSet,
                subTemplate: nil
            ),
            tileContext: .search,
            reportContext: .search,
            ratingBadgeItemsFactory: ratingBadgeItemsFactory
        )

        tileVM.createAccessibilityInfo(features: features, labels: labels)

        tileVM.actionsMenuTapped.sink { [weak self] cta in
            guard let self, let tile else { return }
            didTapActionsMenu(
                for: tile.asset,
                with: tileId,
                ctaSets: getActionsMenuCTASets(
                    tile: tile,
                    renderHint: renderHint,
                    tileViewModel: tileVM
                )
            )
        }.store(in: &cancellables)

        return tileVM
    }

    private func typeSearch(
        asset: Asset,
        isPlaceholder: Bool
    ) -> TilesType {

        guard !isPlaceholder else { return .placeholder }

        if asset is Legacy_Api.SingleLiveEvent {
            return .sle
        } else if asset is Legacy_Api.Playlist {
            return .playlist
        } else if let epgEvent = asset as? Legacy_Api.EPGEvent {
            if epgEvent.channelType == .linear {
                return .linearEPG
            } else {
                return .vodPlaylistEPG
            }
        } else if asset is Legacy_Api.WatchLiveProgramModel {
            if asset.type == .bffVodChannel {
                return .vodChannel
            } else {
                return .linear
            }
        } else if asset.isShortform {
            return .clip
        } else {
            return .movies
        }
    }

    // MARK: ActionsMenu
    @MainActor func didTapActionsMenu(
        for asset: Asset,
        with tileId: String,
        ctaSets: [CTASpec]?
    ) {

        guard let indexPath = findIndexPathOnItems(of: tileId) else { return }

        let actions = self.getActionsForActionSheet(
            for: asset,
            tileId: tileId,
            ctaSets: ctaSets
        )

        trackDidSelectActionsMenu(for: asset)

        if let actions {
            self.outputEvents.presentActionSheet?(
                SheetOptions(
                    asset: asset,
                    indexPath: indexPath,
                    actions: actions
                )
            )
        }
    }

    @MainActor private func getActionsForActionSheet(
        for asset: Asset,
        tileId: String,
        ctaSets: [CTASpec]?
    ) -> [Action]? {
        if let ctas = ctaSets {
            var actions: [Action] = []

            ctas.forEach { cta in
                let action = self.actionsMenuHelper.createActionsMenuAction(
                    cta: cta,
                    isInMyStuff: myStuffAssetsHandler.assetExistsInMyStuff(asset),
                    callback: { [weak self] _ in
                        guard let self else { return }
                        self.didTapCTASpec(
                            for: asset,
                            tileId: tileId,
                            cta: cta,
                            resolvedAction: self.ctaSpecActionResolver.resolveAction(for: cta),
                            actionsMenuCTASets: ctaSets,
                            context: .actionsMenu,
                            buttonText: nil
                        )
                    }
                )
                actions.append(action)
            }
            return actions
        }
        return nil
    }

    private func getActionsMenuCTASets(
        tile: SearchTile?,
        renderHint: SearchRenderHint?,
        tileViewModel: TileViewModel
    ) -> [CTASpec]? {
        if tile?.asset.type == .bffLinearChannel || tile?.asset.type == .bffVodChannel {
            return tileViewModel.ctaSets
        }
        return ctaSetHelper.makeCTASets(
            tileId: tile?.id,
            pageCTASetKey: nil,
            railCTASetKey: renderHint?.contextMenuCtaSet,
            tileCTASetKey: nil,
            ctasSets: tile?.ctaSets,
            context: .search,
            shouldReport: false
        )
    }

    func findIndexPathOnItems(of tileId: String) -> IndexPath? {
        let selectedTab = searchTabs.getSelectedTab()
        var searchTab = searchTabs.getSearchTab(for: selectedTab)

        if
            searchTab.items.isEmpty,
            selectedTab != .emptySearch
        {
            searchTab = searchTabs.getSearchTab(for: .emptySearch)
        }

        guard let itemIndex = searchTab.items.firstIndex(where: { $0.id == tileId }) else { return nil }

        return IndexPath(item: itemIndex, section: 0)
    }

    func createAssetMetadataItems(
        with asset: Asset,
        options: ActionsMenuApi.AssetMetadataOptionSet,
        maxCharacters: Int
    ) -> [ActionsMenuApi.MetadataItem] {
        return actionsMenuHelper.createAssetMetadataItems(
            with: asset,
            options: options,
            maxCharacters: maxCharacters
        )
    }

    private func streamPosition(_ content: ResolvedAction.Content) -> Int? {
        return switch content {
        case let .programme(streamPosition),
             let .episode(_, streamPosition),
             let .sle(_, streamPosition):
            streamPosition?.value
        case .clip, .trailer, .playlist, .fer, .epgEvent:
            nil
        }
    }

    @objc func dismissActionsMenu() {
        notificationCenter.removeObserver(
            self,
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil
        )
        outputEvents.dismissActionSheet? { }
    }
}

// MARK: - Navigation
extension SearchViewModel {

    private func didTapSearchButton(searchTerm: String) {
        let input: AddRecentSearchTermUseCaseInput = AddRecentSearchTermUseCaseInput(
            searchTerm: searchTerm
        )
        addRecentSearchTermUseCase.execute(input: input)
        outputEvents.presentInputEnded?()
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    @MainActor func didSelect(
        tile: TileViewModel,
        index: Int
    ) {
        if searchTabs.getSelectedTab() == .emptySearch {
            let emptySearchTab = searchTabs.getSearchTab(for: .emptySearch)
            trackSearchPlaceholderAssetSelected(
                asset: tile.asset,
                at: index,
                railName: emptySearchTab.name
            )
        } else if
            let selectedTab = searchTabs.getResults().first(where: { $0.contentFormat == searchTabs.getSelectedTab() }),
            let noResultsReason = selectedTab.searchNoResultsReason {
            let railName = searchTabs.getSearchNoResultsTab(for: searchTabs.getSelectedTab()).railName
            trackSearchPlaceholderAssetSelected(
                asset: tile.asset,
                at: index,
                railName: railName ?? selectedTab.railName ?? "",
                searchNoResultsReason: noResultsReason.rawValue
            )
        } else {
            trackItemSelected(
                asset: tile.asset,
                at: index
            )
        }

        if let parentActionCTA = tile.tileClickCTA {
            didTapCTASpec(
                for: tile.asset,
                tileId: tile.id,
                cta: parentActionCTA,
                resolvedAction: ctaSpecActionResolver.resolveAction(for: parentActionCTA),
                actionsMenuCTASets: nil,
                context: .unknown,
                buttonText: nil
            )
        } else {
            (tile.asset as? Legacy_Api.SingleLiveEvent)?.isMultiview = features.isEnabled(.enableMultiview)
            assetActionValidator.shouldPlay(
                asset: tile.asset,
                template: nil
            ) { [weak self] assetActionValidationResult in
                guard let self = self else { return }

                let shouldRefreshEntitlementsOnStartUpsell = self.features.isEnabled(.entitlementsRefreshStartUpsell)

                let isChannelResult = tile.asset.type == .bffLinearChannel || tile.asset.type == .bffVodChannel
                guard assetActionValidationResult.shouldPlay && !isChannelResult else {
                    if assetActionValidationResult.isPremium && shouldRefreshEntitlementsOnStartUpsell {
                        self.umvTokenRefresher.refreshEntitlements(completion: nil)
                    }
                    if self.shouldShowCollectionGroup(asset: tile.asset) {
                        self.outputEvents.routeToCollection?(assetActionValidationResult.asset)
                    } else if self.shouldOpenGrid(asset: tile.asset) {
                        self.outputEvents.routeToGrid?(assetActionValidationResult.asset)
                    } else if self.shouldOpenChannel(asset: tile.asset) {
                        guard let liveProgram = tile.asset as? WatchLiveProgramModel else { return }
                        self.outputEvents.routeToChannel?(liveProgram)
                    } else {
                        if
                            self.shouldOpenMiniPDP(asset: tile.asset),
                            searchTabs.getSelectedTab() == .emptySearch,
                            let rail = popularSearchRail
                        {
                            let miniPDPAnalyticsDataSource: MiniPDPAnalyticsDataSourceImpl = .init(
                                asset: tile.asset,
                                railName: nil,
                                searchTabType: .emptySearch,
                                hasTuneInBadging: tile.shouldDisplayTuneInBadging
                            )
                            self.eventHub.emit(SearchTileClick())
                            self.outputEvents.routeToMiniPdp?(rail.railId, tile.id, self, miniPDPAnalyticsDataSource)
                        } else {
                            self.eventHub.emit(SearchTileClick())
                            self.outputEvents.routeToPdp?(assetActionValidationResult.asset)
                        }
                    }
                    return
                }

                guard assetActionValidationResult.isPremium else {
                    self.outputEvents.routeToPlayer?(assetActionValidationResult.asset)
                    return
                }
                if shouldRefreshEntitlementsOnStartUpsell {
                    self.refreshEntitlements(assetActionValidationResult.asset)
                } else {
                    routeToUpsell(asset: assetActionValidationResult.asset)
                }
            }
        }
    }

    private func shouldOpenGrid(asset: Legacy_Api.Asset) -> Bool {
        return asset.linkType == .grid
    }

    private func shouldShowCollectionGroup(asset: Legacy_Api.Asset) -> Bool {
        return asset.type == .group
    }

    private func shouldOpenChannel(asset: Legacy_Api.Asset) -> Bool {
        if
            asset.type == .linearSlot ||
            asset.type == .bffLinearChannel ||
            asset.type == .bffVodChannel {
            return true
        }

        if let epgEvent = asset as? EPGEvent {
            if epgEvent.channelType == .vod { return true }

            if features.isEnabled(.epgAssetLinearPdp) {
                return epgEvent.eventStage == .live
            } else {
                return true
            }
        }

        return false
    }

    private func shouldOpenMiniPDP(asset: Legacy_Api.Asset) -> Bool {
        return features.isEnabled(.miniPdp) && miniPDPTileFilter.accepts(tile: nil, asset: asset)
    }

    func routeToUpsell(asset: Asset, from cta: CTASpec? = nil) {
        let upsellContentSegments = if let cta {
            UpsellContentSegments(cta: cta)
        } else {
            UpsellContentSegments(asset: asset)
        }

        outputEvents.routeToUpsellJourney?(asset, upsellContentSegments)
    }
}

// MARK: - UserEntitlementsRefreshListener
extension SearchViewModel: UserEntitlementsRefreshListener {
    public func didRefreshEntitlements() {
        refresh(forced: true)
    }

    private func refresh(forced: Bool = false) {
        let currentTab = self.searchTabs.getSelectedTab()

        self.resetResults()

        switch currentTab {
        case .emptySearch:
            self.fetchPlaceholderCollection(
                contentFormat: .emptySearch,
                forceUpdate: forced
            )
        case .longform, .clip:
            let searchResults: SearchResults = SearchResults(
                tabs: self.searchTabs.getResults()
            )
            self.mainQueue.async {
                self.outputEvents.presentResults?(
                    searchResults,
                    currentTab
                )
            }

            guard let lastSearchTerm else { return }

            observeSearchResults(
                searchTerm: lastSearchTerm,
                contentFormat: lastContentFormat
            )
        }
    }
}

// MARK: - NegativeFeedbackTrackable
extension SearchViewModel: NegativeFeedbackTrackable {
    public func getImageURLQueryParameters(forIndex index: Int) -> [String: String] {
        let selectedTab = searchTabs.getSelectedTab()
        let resultsForSelectedTab = searchTabs.getSearchTab(for: selectedTab)

        guard resultsForSelectedTab.items.count > index else {
            return [:]
        }

        let imageURLQueryParameters = Self.generateParameters(
            asset: resultsForSelectedTab.items[index].asset, railTitle: "",
            negativeFeedbackTrackingEnabled: features.isEnabled(.negativeFeedbackTracking),
            generator: self.imageURLParametersGenerator
        ).parameters

        return imageURLQueryParameters
    }
}

// MARK: - Tile Updates
extension SearchViewModel {
    var tilesDidChange: AnyPublisher<TileUpdates<String>, Never> {
        return observeTilesUseCase
            .execute(input: getChannelsMenuSectionNavigationUseCase.execute())
            .map { updates in
                TileUpdates(
                    changed: updates.receivedIds,
                    failed: updates.failedIds,
                    removed: updates.removableIds
                )
            }
            .eraseToAnyPublisher()
    }

    private func observeContextChanges() {
        let hasBouquetChangesPublisher = observeLocalisationBouquetChangesUseCase.execute()
            .map { current, previous in
                return current != previous
            }
            .eraseToAnyPublisher()

        let hasTerritoryChangesPublisher = observeLocalisationTerritoryChangesUseCase.execute()
            .map { current, previous in
                return current != previous
            }
            .eraseToAnyPublisher()

        let hasServerTimeOffsetChangesPublisher = observeServerTimeOffsetChangesUseCase.execute()
            .map { return true }
            .eraseToAnyPublisher()

        let hasUserDetailsChangesPublisher = observeUserDetailsChangesUseCase.execute()
            .map { current, previous in
                return !self.isEqual(current: current, previous: previous)
            }
            .eraseToAnyPublisher()

        contextChangesSubscription = hasTerritoryChangesPublisher
            .merge(with: hasBouquetChangesPublisher)
            .merge(with: hasServerTimeOffsetChangesPublisher)
            .merge(with: hasUserDetailsChangesPublisher)
            .filter { $0 == true } // Continue to request refresh only if something changed
            .throttle(for: 0.5, scheduler: contextChangesScheduler, latest: false)
            .mapToVoid()
            .sink(receiveValue: { [weak self] in
                self?.mainQueue.async {
                    self?.refresh()
                }
        })
    }

    private func isEqual(current: OVPUserDetailsData, previous: OVPUserDetailsData) -> Bool {
        // Compare Sets to ensure order does not affect equality
        let areAccountsEqual = Set(current.segmentation?.account ?? []) == Set(previous.segmentation?.account ?? [])
        let areContentsEqual = Set(current.segmentation?.content ?? []) == Set(previous.segmentation?.content ?? [])
        let areDiscoveriesEqual = Set(current.segmentation?.discovery ?? []) == Set(previous.segmentation?.discovery ?? [])
        let areEntitlementsEqual = Set(current.entitlements ?? []) == Set(previous.entitlements ?? [])

        return areAccountsEqual &&
        areContentsEqual &&
        areDiscoveriesEqual &&
        areEntitlementsEqual &&
        current.segmentation?.notification == previous.segmentation?.notification &&
        current.providerTerritory == previous.providerTerritory &&
        current.homeTerritory == previous.homeTerritory
    }
}

// MARK: - PushNotificationManagerObserver
extension SearchViewModel: PushNotificationManagerObserver {
    var shouldShowNotification: Bool {
        return true
    }
}
