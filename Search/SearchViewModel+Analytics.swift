import ActionsMenuApi
import Analytics
import AppReportingApi
import Browse_Api
import BrowseApi
import Core_Ui_Api
import GSTCoreServicesContinueWatchingApi
import Legacy_Api
import PCLSBrowseChannelsCoreApi
import PCLSContinueWatchingApi

// swiftlint:disable file_length
extension SearchViewModel {
    func trackOpen() {
        analytics.track(event: .search(.searchPageDisplayed))

        let selectedTab = searchTabs.getSelectedTab()
        if selectedTab == .emptySearch {
            analytics.track(event: .search(.searchEmptyStateDisplayed))
        }
    }

    func trackExit() {
        let selectedTab = searchTabs.getSelectedTab()
        let resultsForSelectedTab = searchTabs.getSearchTab(for: selectedTab)
        let tabType: Analytics.SearchData.TabType = selectedTab == .clip ? .clips : .results

        analytics.track(
            event:
            .search(
                .exitedSearch(search:
                    .init(
                        searchResults: resultsForSelectedTab.items.count,
                        searchTerm: lastSearchTerm,
                        tabType: tabType
                    )
                )
            )
        )
    }

    func trackCancel(term: String?, areResultsVisible: Bool) {
        let selectedTab = searchTabs.getSelectedTab()
        let resultsForSelectedTab = searchTabs.getSearchTab(for: selectedTab)
        let count = resultsForSelectedTab.items.count

        analytics.track(
            event: .search(
                .cancelledSearch(
                    search: .init(
                        assetData: nil,
                        searchResults: areResultsVisible ? count : nil,
                        searchTerm: term,
                        tabType: lastContentFormat == .clip ? .clips : .results
                    )
                )
            )
        )
    }

    func trackItemSelected(asset: Legacy_Api.Asset, at index: Int) {
        let selectedTab = searchTabs.getSelectedTab()
        let resultsForSelectedTab = searchTabs.getSearchTab(for: selectedTab)
        let isTuneInBadging = TuneInBadgingDisplayBusinessLogic.item(asset, features).shouldDisplayTuneInBadging
        let metadata = AnalyticsUtils.convertAsset(
            from: asset,
            badges: isTuneInBadging ? [BadgingInfo.BadgeAnalyticsLabel.tune_in] : nil
        )
        let tabType = analyticsTabType(searchContentFormat: selectedTab)
        let searchType = asset.matchReason?.replacingOccurrences(of: " ", with: "_").lowercased()

        let indexPath = AnalyticsUtils.createRailsColumnIndex(
            for: index,
            numberOfItemsPerRow: outputEvents.numberOfItemsPerRow?() ?? .zero
        )

        analytics.track(
            event:
            .search(
                .assetSelected(
                    search: .init(
                        assetData: .init(
                            index: index,
                            row: indexPath.row,
                            column: indexPath.section,
                            metadata: metadata
                        ),
                        searchObjectId: asset.objectId,
                        searchQueryId: asset.queryId,
                        searchResults: resultsForSelectedTab.items.count,
                        searchTerm: lastSearchTerm,
                        searchType: searchType,
                        tabType: tabType
                    )
                )
            )
        )
    }

    func analyticsTabType(searchContentFormat: SearchContentFormat) -> Analytics.SearchData.TabType {
        switch searchContentFormat {
        case .emptySearch:
            return .emptySearch
        case .longform:
            return .results
        case .clip:
            return .clips
        }
    }

    func trackSearchResults(
        selectedTab: SearchContentFormat,
        results: [SearchTab],
        searchTerm: String?
    ) {
        let resultsForSelectedTab = results.first(where: { $0.contentFormat == selectedTab })

        guard
            let resultsForSelectedTab,
            !resultsForSelectedTab.items.isEmpty
        else {
            let searchType = resultsForSelectedTab?.searchNoResultsReason?.rawValue

            analytics.track(
                event:
                .search(
                    .searchWithoutResults(
                        search:
                        .init(
                            searchResults: .zero,
                            searchTerm: searchTerm,
                            searchType: searchType,
                            tabType: selectedTab == .clip ? .clips : .results
                        )
                    )
                )
            )
            return
        }

        analytics.track(
            event:
            .search(
                .searchWithResults(
                    search:
                    .init(
                        searchResults: resultsForSelectedTab.items.count,
                        searchTerm: searchTerm,
                        searchType: nil,
                        tabType: selectedTab == .clip ? .clips : .results
                    )
                )
            )
        )
    }

    func trackExceededMaturityRating(for asset: Legacy_Api.Asset?) {
        analytics.track(event: .search(.didShowMaturitRatingErrorNotification(assetMetadata: AnalyticsUtils.convertAsset(from: asset))))
    }

    //swiftlint:disable:next function_body_length
    func trackActionsMenu(
        with asset: Asset,
        tileId: String,
        resolvedAction: ResolvedAction,
        cta: CTASpec
    ) {
        guard let index = findIndexPathOnItems(of: tileId)?.item else { return }
        let indexPath = AnalyticsUtils.createRailsColumnIndex(
            for: index,
            numberOfItemsPerRow: outputEvents.numberOfItemsPerRow?() ?? .zero
        )
        let selectedTab = searchTabs.getSelectedTab()
        let tabType = analyticsTabType(searchContentFormat: selectedTab)

        let hasTuneInBadging = TuneInBadgingDisplayBusinessLogic.item(asset, features).shouldDisplayTuneInBadging
        switch resolvedAction {
        case .watchlist:
            let isInMyStuff = myStuffAssetsHandler.assetExistsInMyStuff(asset)
            analytics.track(event: .actionMenu(
                .handleMyStuffCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    position: indexPath.section,
                    railIndex: indexPath.row,
                    section: "",
                    railName: "",
                    tabType: tabType,
                    isInMyStuff: isInMyStuff,
                    isCWCollection: false,
                    isCollection: false,
                    isImmersive: false,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .upsell:
            analytics.track(event: .actionMenu(
                .upgradeCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    position: indexPath.section,
                    railIndex: indexPath.row,
                    section: "",
                    railName: "",
                    tabType: tabType,
                    isCWCollection: false,
                    isCollection: false,
                    isImmersive: false,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .play(let content):
            let isTrailer = cta.renderHint?.style == .trailer
            if let seconds = streamPosition(content), seconds > 0 {
                analytics.track(event: .actionMenu(
                    .resumeCTAClick(
                        asset: AnalyticsUtils.convertAsset(from: asset),
                        position: indexPath.section,
                        railIndex: indexPath.row,
                        section: "",
                        railName: "",
                        tabType: tabType,
                        isCWCollection: false,
                        isCollection: false,
                        isImmersive: false,
                        hasTuneInBadging: hasTuneInBadging
                    )
                ))
            } else {
                analytics.track(event: .actionMenu(
                    .watchCTAClick(
                        asset: AnalyticsUtils.convertAsset(from: asset),
                        position: indexPath.section,
                        railIndex: indexPath.row,
                        section: "",
                        railName: "",
                        tabType: tabType,
                        isTrailer: isTrailer,
                        isCWCollection: false,
                        isCollection: false,
                        isImmersive: false,
                        hasTuneInBadging: hasTuneInBadging
                    )
                ))
            }
        case .pdp:
            analytics.track(event: .actionMenu(
                .moreInfoCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    position: indexPath.section,
                    railIndex: indexPath.row,
                    section: "",
                    railName: "",
                    tabType: tabType,
                    isCWCollection: false,
                    isCollection: false,
                    isImmersive: false,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .channelGuide, .open, .continueWatching, .unresolved:
            // Doesn't have analytics at the moment.
            break
        }
    }

    //swiftlint:disable:next function_body_length
    func trackMiniPDP(
        with asset: Asset,
        tileId: String,
        resolvedAction: ResolvedAction,
        cta: CTASpec,
        buttonText: String?
    ) {
        guard let index = findIndexPathOnItems(of: tileId)?.item else { return }
        let indexPath = AnalyticsUtils.createRailsColumnIndex(
            for: index,
            numberOfItemsPerRow: outputEvents.numberOfItemsPerRow?() ?? .zero
        )
        let selectedTab = searchTabs.getSelectedTab()
        let tabType = analyticsTabType(searchContentFormat: selectedTab)

        let hasTuneInBadging = TuneInBadgingDisplayBusinessLogic.item(asset, features).shouldDisplayTuneInBadging

        switch resolvedAction {
        case .watchlist:
            let isInMyStuff = myStuffAssetsHandler.assetExistsInMyStuff(asset)
            analytics.track(event: .miniPDP(
                .handleMyStuffCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    railName: "",
                    tabType: tabType,
                    isInMyStuff: isInMyStuff,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .upsell:
            analytics.track(event: .miniPDP(
                .upgradeCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    railName: "",
                    tabType: tabType,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .play(let content):
            if let seconds = streamPosition(content), seconds > 0 {
                analytics.track(event: .miniPDP(
                    .resumeCTAClick(
                        asset: AnalyticsUtils.convertAsset(from: asset),
                        railName: "",
                        tabType: tabType,
                        hasTuneInBadging: hasTuneInBadging
                    )
                ))
            } else {
                analytics.track(event: .miniPDP(
                    .watchCTAClick(
                        asset: AnalyticsUtils.convertAsset(from: asset),
                        railName: "",
                        tabType: tabType,
                        hasTuneInBadging: hasTuneInBadging,
                        textLabel: buttonText
                    )
                ))
            }
        case .pdp:
            analytics.track(event: .miniPDP(
                .moreInfoCTAClick(
                    asset: AnalyticsUtils.convertAsset(from: asset),
                    railName: "",
                    tabType: tabType,
                    hasTuneInBadging: hasTuneInBadging
                )
            ))
        case .channelGuide, .open, .continueWatching, .unresolved:
            break
        }
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

    func trackDidSwitchSearchTab() {
        analytics.track(event: .search(.searchEmptyStateDisplayed))
    }

    func trackSearchPlaceholderAssetSelected(
        asset: Legacy_Api.Asset,
        at index: Int,
        railName: String,
        searchNoResultsReason: String? = nil
    ) {
        let isTuneInBadging = TuneInBadgingDisplayBusinessLogic.item(asset, features).shouldDisplayTuneInBadging
        let searchTerm = searchNoResultsReason != nil ? lastSearchTerm : nil
        let indexPath = AnalyticsUtils.createRailsColumnIndex(
            for: index,
            numberOfItemsPerRow: outputEvents.numberOfItemsPerRow?() ?? .zero
        )
        analytics.track(
            event:
            .search(
                .searchEmptyStateAssetSelected(
                    search: .init(
                        assetData: .init(
                            index: index,
                            row: indexPath.row,
                            column: indexPath.section,
                            metadata: AnalyticsUtils.convertAsset(
                                from: asset,
                                badges: isTuneInBadging ? [BadgingInfo.BadgeAnalyticsLabel.tune_in] : nil)
                        ),
                        searchResults: .zero,
                        searchTerm: searchTerm,
                        searchType: EmptySearchReason.noMatch.rawValue,
                        tabType: .emptySearch
                    ),
                    railName: railName
                )
            )
        )
    }

    func trackDidSelectActionsMenu(for asset: Asset) {
        let selectedTab = searchTabs.getSelectedTab()
        let tabType = analyticsTabType(searchContentFormat: selectedTab)
        analytics.track(event: .actionMenu(
            .actionMenuClick(
                asset: AnalyticsUtils.convertAsset(from: asset),
                section: "",
                railName: "",
                tabType: tabType,
                isCWCollection: false,
                isCollection: false,
                isImmersive: false
            )
        ))
    }
}

extension SearchViewModel {
    enum AnalyticsConstants {
        static let episodePlaceholder = "episodeNumber"
        static let seasonPlaceholder = "seasonNumber"
    }
}
