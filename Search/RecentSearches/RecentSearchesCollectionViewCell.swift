import UIKit

final class RecentSearchesCollectionViewCell: UICollectionViewCell {
    // MARK: Consts
    private var style = SearchStyle.RecentSearchesStyle.defaultStyle()

    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = style.textColor
        titleLabel.font = style.font
        return titleLabel
    }()

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = ""
        titleLabel.textColor = style.textColor
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
        setupTitleLabel()
        addSubviewAndPinEdges(titleLabel)
    }

    // MARK: Methods
    private func setupTitleLabel() {
        titleLabel.font = style.font
        titleLabel.textColor = style.textColor
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}
