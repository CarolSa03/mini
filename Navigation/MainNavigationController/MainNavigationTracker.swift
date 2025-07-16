protocol MainNavigationTracking {
    func trackItemSelected(viewModeType: ViewingModeType)
}

final class MainNavigationTracker: MainNavigationTracking {
    private var analyticsService: AnalyticsServiceProtocol

    init(analyticsService: AnalyticsServiceProtocol = Dependency.resolve(AnalyticsServiceProtocol.self)) {
        self.analyticsService = analyticsService
    }

    func trackItemSelected(viewModeType: ViewingModeType) {
        guard viewModeType != .search else { return }
        analyticsService.trackClick(of: ViewingModeControlConfiguration.clickedItemName(viewModeType))
    }
}
