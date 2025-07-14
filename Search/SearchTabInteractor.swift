import AppSettings_Api
import AppSettings_Impl
import Foundation
import Legacy_Api
import PCLSLabelsApi

protocol SearchTabLogic {
    var isEmptySearchRailCached: Bool { get }
    var isNoResultsLongformRailCached: Bool { get }
    var isNoResultsClipRailCached: Bool { get }

    func getResults() -> [SearchTab]
    func getSearchNoResultsTab(for contentFormat: SearchContentFormat) -> SearchTab
    func getSearchTab(for contentFormat: SearchContentFormat) -> SearchTab
    func resetTabs()
    func buildEmptySearchResults(with rail: CollectionGroupRail, renderHint: SearchRenderHint?)
    func buildNoLongFormResultsAssets(with rail: CollectionGroupRail)
    func buildNoClipResultsAssets(with rail: CollectionGroupRail)
    func buildResults(with searchResult: SearchServiceResults)
    func switchTab(to contentFormat: SearchContentFormat)
    func getSelectedTab() -> SearchContentFormat
}

final class SearchTabInteractor: SearchTabLogic {
    var isEmptySearchRailCached: Bool = false
    var isNoResultsLongformRailCached: Bool = false
    var isNoResultsClipRailCached: Bool = false

    // MARK: Inner types
    private lazy var longFormResults: SearchTab = {
        return SearchTab(
            searchTerm: nil,
            contentFormat: .longform,
            items: [SearchTile](),
            isLoading: false,
            name: LocalizationKeys.Search.Results.localizedString
        )
    }()

    private lazy var shortFormResults: SearchTab = {
        return SearchTab(
            searchTerm: nil,
            contentFormat: .clip,
            items: [SearchTile](),
            isLoading: false,
            name: LocalizationKeys.Search.Clips.localizedString
        )
    }()

    private lazy var emptySearchTab: SearchTab = .init(
        searchTerm: nil,
        contentFormat: .emptySearch,
        items: [SearchTile](),
        isLoading: true,
        name: ""
    )

    private lazy var noLongFormResultsPlaceholder: SearchTab = .init(
        searchTerm: nil,
        contentFormat: .longform,
        items: [],
        isLoading: true,
        name: labels.getLabel(forKey: LocalizationKeys.Search.Results),
        searchNoResultsReason: EmptySearchReason.noMatch
    )

    private lazy var noClipResultsPlaceholder: SearchTab = .init(
        searchTerm: nil,
        contentFormat: .clip,
        items: [],
        isLoading: true,
        name: labels.getLabel(forKey: LocalizationKeys.Search.Clips),
        searchNoResultsReason: EmptySearchReason.noMatch
    )

    // MARK: Properties

    private var selectedTab: SearchContentFormat = .emptySearch
    private let features: Features
    private let labels: Labels

    init(
        features: Features = Dependency.resolve(Features.self),
        labels: Labels = Dependency.resolve(Labels.self)
    ) {
        self.features = features
        self.labels = labels
    }
}

extension SearchTabInteractor {
    // MARK: Methods

    func getResults() -> [SearchTab] {
        if features.isEnabled(.shortformSearch) {
            return [longFormResults, shortFormResults]
        }
        return [longFormResults]
    }

    func getSearchTab(for contentFormat: SearchContentFormat) -> SearchTab {
        switch contentFormat {
        case .longform:
            return longFormResults
        case .clip:
            return shortFormResults
        case .emptySearch:
            return emptySearchTab
        }
    }

    func getSearchNoResultsTab(for contentFormat: SearchContentFormat) -> SearchTab {
        switch contentFormat {
        case .longform:
            return noLongFormResultsPlaceholder
        case .clip:
            return noClipResultsPlaceholder
        case .emptySearch:
            return emptySearchTab
        }
    }

    func resetTabs(
        for contentFormat: SearchContentFormat,
        searchTerm: String?
    ) {

        if features.isEnabled(.shortformSearch) {
            shortFormResults = resetSearchTab(
                using: shortFormResults,
                isLoading: shortFormResults.contentFormat == contentFormat,
                searchTerm: searchTerm
            )
        }

        longFormResults = resetSearchTab(
            using: longFormResults,
            isLoading: longFormResults.contentFormat == contentFormat,
            searchTerm: searchTerm
        )
    }

    func resetTabs() {
        if features.isEnabled(.shortformSearch) {
            shortFormResults = resetSearchTab(
                using: shortFormResults,
                isLoading: true,
                searchTerm: shortFormResults.searchTerm
            )
        }

        longFormResults = resetSearchTab(
            using: longFormResults,
            isLoading: true,
            searchTerm: longFormResults.searchTerm
        )
    }

    private func resetSearchTab(
        using searchTab: SearchTab,
        isLoading: Bool,
        searchTerm: String?
    ) -> SearchTab {
        return SearchTab(
            searchTerm: searchTerm,
            contentFormat: searchTab.contentFormat,
            items: [SearchTile](),
            isLoading: isLoading,
            name: searchTab.name
        )
    }

    func buildEmptySearchResults(with rail: CollectionGroupRail, renderHint: SearchRenderHint?) {
        isEmptySearchRailCached = true

        emptySearchTab = SearchTab(
            searchTerm: nil,
            contentFormat: .emptySearch,
            items: rail.items.map { SearchTile(id: $0.identifier, asset: $0, ctaSets: nil) },
            isLoading: false,
            name: rail.attributes.title,
            renderHint: renderHint
        )
    }

    func buildNoLongFormResultsAssets(with rail: CollectionGroupRail) {
        isNoResultsLongformRailCached = true

        noLongFormResultsPlaceholder = SearchTab(
            searchTerm: nil,
            contentFormat: .longform,
            items: rail.items.map { SearchTile(id: $0.identifier, asset: $0, ctaSets: nil) },
            isLoading: false,
            name: labels.getLabel(forKey: LocalizationKeys.Search.Results),
            searchNoResultsReason: EmptySearchReason.noMatch,
            railName: rail.attributes.title
        )
    }

    func buildNoClipResultsAssets(with rail: CollectionGroupRail) {
        isNoResultsClipRailCached = true

        noClipResultsPlaceholder = SearchTab(
            searchTerm: nil,
            contentFormat: .clip,
            items: rail.items.map { SearchTile(id: $0.identifier, asset: $0, ctaSets: nil) },
            isLoading: false,
            name: labels.getLabel(forKey: LocalizationKeys.Search.Clips),
            searchNoResultsReason: EmptySearchReason.noMatch,
            railName: rail.attributes.title
        )
    }

    func buildResults(with searchResult: SearchServiceResults) {
        longFormResults = searchTabBuilderFor(contentFormat: .longform, searchResult: searchResult)
        if features.isEnabled(.shortformSearch) {
            shortFormResults = searchTabBuilderFor(contentFormat: .clip, searchResult: searchResult)
        }
    }

    func switchTab(to contentFormat: SearchContentFormat) {
        selectedTab = contentFormat
    }

    func getSelectedTab() -> SearchContentFormat {
        return selectedTab
    }

    private func searchTabBuilderFor(contentFormat format: SearchContentFormat, searchResult: SearchServiceResults) -> SearchTab {
        let results = getResultsByFormat(contentFormat: format, searchResult: searchResult)
        let resultsTiles = results?.tiles.filter { $0.asset != Legacy_Api.Asset() }
        let name = (format == .longform ? LocalizationKeys.Search.Results.localizedString : LocalizationKeys.Search.Clips.localizedString)
        let searchTab: SearchTab = .init(
            searchTerm: searchResult.term,
            contentFormat: format,
            items: (searchResult.isSearching ? [SearchTile]() : resultsTiles) ?? [SearchTile](),
            isLoading: results?.tiles == nil ? true : searchResult.isSearching,
            name: name,
            searchNoResultsReason: results?.searchNoResultsReason,
            renderHint: results?.renderHint
        )

        if
            results == nil,
            format == .emptySearch
        {
            return emptySearchTab
        } else {
            return searchTab
        }
    }

    private func getResultsByFormat(
        contentFormat format: SearchContentFormat,
        searchResult: SearchServiceResults
    ) -> SearchServiceResults.SearchItems? {
        switch format {
        case .longform:
            return searchResult.searchResults
        case .clip:
            return searchResult.clipsResults
        case .emptySearch:
            return nil
        }
    }
}
