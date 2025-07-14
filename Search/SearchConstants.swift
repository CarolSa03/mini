import Foundation

struct SearchConstants {
    enum AccessibilityIdentifiers {
        static let emptySearchLabel = "empty_search_label"
        static let noContentLabel = "no_results_label"
        static let noResultsCollectionLabel = "no_results_collection_label"
        static let failedLoadingLabel = "failed_loading_label"
        static let textField = "search_text_field"
    }

    static let maxNumberOfRecentSearches = 5
    static let minTabsToShowBar = 2
    static let searchDebounceTimeInSeconds = 0.5
    static let upcomingFeatureQueryParameter = "upcoming"
    static let searchTypeStringSeparator = "-"
}
