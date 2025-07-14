import UIKit

struct NoContentLabelStyle {
    let font: UIFont
    let textColor: UIColor
    let text: String
    let accessibilityIdentifier: String
}

struct SearchStyle {

    struct SearchBarStyle {
        let textColor: UIColor
        let tintColor: UIColor

        let placeholderTextColor: UIColor
        let accessibilityIdentifier: String
        let backgroundColor: UIColor

        func font(for traitCollection: UITraitCollection) -> UIFont {
            let fontSize = traitCollection.isRegularRegular
                ? Constants.regularFontSize
                : Constants.compactFontSize
            return Theme.shared.regularFont(size: fontSize)
        }

        func placeholderFont(for traitCollection: UITraitCollection) -> UIFont {
            let fontSize = traitCollection.isRegularRegular
                ? Constants.regularFontSize
                : Constants.compactFontSize
            return Theme.shared.regularFont(size: fontSize)
        }

        func searchIconHorizontalOffset(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular
                ? Constants.searchIconRegularRegularOffset
                : Constants.searchIconCompactOffset
        }

        func searchIconSize(for traitCollection: UITraitCollection) -> CGSize {
            return traitCollection.isRegularRegular
                ? Constants.searchIconRegularRegularSize
                : Constants.searchIconCompactSize
        }

        func resizeIcon(
            _ icon: UIImage,
            into size: CGSize
        ) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                icon.draw(in: CGRect(
                    origin: .zero,
                    size: size
                ))
            }
        }

        public static func defaultStyle() -> SearchBarStyle {
            return SearchBarStyle(textColor: Theme.Search.TextField.textColor,
                                  tintColor: Theme.Search.TextField.tintColor,
                                  placeholderTextColor: Theme.Search.TextField.placeholderTextColor,
                                  accessibilityIdentifier: SearchConstants.AccessibilityIdentifiers.textField,
                                  backgroundColor: Theme.Search.TextField.backgroundColor)
        }

        private enum Constants {
            static let searchIconCompactOffset: CGFloat = 10.0
            static let searchIconCompactSize: CGSize = CGSize(
                width: 16.0,
                height: 16.0
            )
            static let searchIconRegularRegularOffset: CGFloat = 18.0
            static let searchIconRegularRegularSize: CGSize = CGSize(
                width: 24.0,
                height: 24.0
            )
            static let compactFontSize: CGFloat = 16.0
            static let regularFontSize: CGFloat = 20.0
        }
    }

    struct SearchViewControllerStyle {
        let loadingSpinnerConfiguration: LoadingSpinnerViewConfiguration
        let noContentLabel: NoContentLabelStyle
        let noResultsLabel: NoContentLabelStyle
        let failedLoadingErrorMessage: String
        let backgroundColor: UIColor

        public static func defaultStyle() -> SearchViewControllerStyle {
            return SearchViewControllerStyle(loadingSpinnerConfiguration: LoadingSpinnerViewConfiguration(backgroundColor: Theme.Seamless.backgroundColor,
                                                                                                          overridingPresentationDelay: 0),
                                             noContentLabel: NoContentLabelStyle(font: Theme.shared.boldFont(size: 18),
                                                                                 textColor: Theme.Search.ResultsView.noResultsTextColor,
                                                                                 text: LocalizationKeys.Search.NoOcurrences.localizedString,
                                                                                 accessibilityIdentifier: SearchConstants.AccessibilityIdentifiers.noContentLabel),
                                             noResultsLabel: NoContentLabelStyle(font: Theme.shared.boldFont(size: 18),
                                                                                 textColor: Theme.Search.ResultsView.noResultsTextColor,
                                                                                 text: LocalizationKeys.Search.NoResults.localizedString,
                                                                                 accessibilityIdentifier: SearchConstants.AccessibilityIdentifiers.noContentLabel),
                                             failedLoadingErrorMessage: LocalizationKeys.Error.Generic.localizedString,
                                             backgroundColor: Theme.Seamless.backgroundColor)
        }
    }

    struct RecentSearchesStyle {

        let rowHeight: CGFloat = 40.0
        let headerFont = Theme.shared.regularFont(size: 18.0)
        let headerTextColor = Theme.Search.ResultsView.recentSearchesHeaderTextColor

        let font = Theme.shared.regularFont(size: 20.0)
        let textColor = Theme.Search.ResultsView.recentSearchesTextColor

        public static func defaultStyle() -> RecentSearchesStyle {
            return RecentSearchesStyle()
        }

        func sectionInset(_ traitCollection: UITraitCollection) -> UIEdgeInsets {
            return UIEdgeInsets(top: .zero, left: horizontalSectionInsets(traitCollection), bottom: .zero, right: horizontalSectionInsets(traitCollection))
        }

        private func horizontalSectionInsets(_ traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 32.0 : 35.0
        }
    }

    struct ResultsTabHeaderStyle {
        let textColorNormal: UIColor
        let textColorSelected: UIColor
        let textColorEmptySearch: UIColor

        func font(for traitCollection: UITraitCollection) -> UIFont {
            return traitCollection.isRegularRegular ? Theme.shared.boldFont(size: 28.0) : Theme.shared.boldFont(size: 20.0)
        }

        public static func defaultStyle() -> ResultsTabHeaderStyle {
            return ResultsTabHeaderStyle(
                textColorNormal: Theme.Search.ResultsView.tabHeaderTitleTextColorNormal,
                textColorSelected: Theme.Search.ResultsView.tabHeaderTitleTextColorSelected,
                textColorEmptySearch: Theme.Search.ResultsView.tabHeaderTitleTextColorEmptySearch
            )
        }
    }

    let searchViewControllerStyle: SearchViewControllerStyle
    let searchBarStyle: SearchBarStyle
    let recentSearchesStyle: RecentSearchesStyle
    let resultsTabHeaderStyle: ResultsTabHeaderStyle

    public static func defaultStyle() -> SearchStyle {
        return SearchStyle(searchViewControllerStyle: SearchViewControllerStyle.defaultStyle(),
                           searchBarStyle: SearchStyle.SearchBarStyle.defaultStyle(),
                           recentSearchesStyle: SearchStyle.RecentSearchesStyle.defaultStyle(),
                           resultsTabHeaderStyle: SearchStyle.ResultsTabHeaderStyle.defaultStyle())
    }
}
