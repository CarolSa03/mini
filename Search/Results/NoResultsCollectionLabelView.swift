import UIKit

final class NoResultsCollectionLabelView: UIView {

    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with configuration: NoContentLabelStyle) {
        messageLabel.text = configuration.text
        messageLabel.font = configuration.font
        messageLabel.accessibilityIdentifier = SearchConstants.AccessibilityIdentifiers.noResultsCollectionLabel
        messageLabel.textColor = configuration.textColor
        messageLabel.numberOfLines = 2
    }

    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textAlignment = .center
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: leadingAnchor, multiplier: 1.0)
        ])
    }
}
