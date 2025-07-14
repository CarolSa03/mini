import UIKit

class SearchResultTabViewCell: UICollectionViewCell {
    private var style = SearchStyle.ResultsTabHeaderStyle.defaultStyle()
    private var format: SearchContentFormat = .longform

    private lazy var tabTitleLabel: UILabel = {
        let tabTitleLabel = UILabel()
        tabTitleLabel.text = ""
        tabTitleLabel.textColor = style.textColorNormal
        tabTitleLabel.font = style.font(for: traitCollection)
        return tabTitleLabel
    }()

    override var isSelected: Bool {
        didSet {
            setAppearance()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tabTitleLabel.text = ""
        tabTitleLabel.textColor = style.textColorNormal
        tabTitleLabel.accessibilityIdentifier = ""
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpViews() {
        contentView.addSubviewAndPinEdges(tabTitleLabel)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    private func setAppearance() {
        if case .emptySearch = format {
            tabTitleLabel.textColor = style.textColorEmptySearch
        } else if isSelected {
            tabTitleLabel.textColor = style.textColorSelected
        } else {
            tabTitleLabel.textColor = style.textColorNormal
        }
    }

    func configureWith(
        tabTitle: String,
        style: SearchStyle.ResultsTabHeaderStyle,
        format: SearchContentFormat
    ) {
        tabTitleLabel.text = tabTitle
        tabTitleLabel.accessibilityIdentifier = String(format: AutomationConstants.Search.searchTab, tabTitle)
        self.style = style
        self.format = format
        setAppearance()
    }
}
