import UIKit

final class SearchCollectionViewHeader: UICollectionReusableView {
    static let identifier = "SearchCollectionViewHeader"
    private var style = SearchStyle.RecentSearchesStyle.defaultStyle()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = LocalizationKeys.Search.RecentSearches.localizedString
        titleLabel.font = style.headerFont
        titleLabel.textColor = style.headerTextColor
        backgroundColor = .clear

        let insets = style.sectionInset(traitCollection)
        addSubview(titleLabel)
        titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: .zero - insets.left - insets.right).isActive = true
        titleLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        accessibilityIdentifier = "recentSearches-header"
    }
}
