import UIKit

protocol SearchBarViewDelegate: AnyObject {
    func didBeginEditing()
    func didBeginSearch(for text: String?, type: SearchType)
    func didEndSearch()
}

class SearchBar: UISearchBar {
    private let searchIcon = UIImage(imageLiteralResourceName: "Search")
    private let clearIcon = UIImage(imageLiteralResourceName: "clearIcon")
    private var debounceTimer: Timer?

    private var style: SearchStyle.SearchBarStyle

    private(set) var isSearchActive = false

    weak var searchDelegate: SearchBarViewDelegate?

    var localizedPlaceholderText: String?

    override init(frame: CGRect) {
        style = SearchStyle.SearchBarStyle.defaultStyle()
        super.init(frame: frame)
        initialSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        style = SearchStyle.SearchBarStyle.defaultStyle()
        super.init(coder: aDecoder)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        initialSetup()
    }

    private func initialSetup() {
        delegate = self
        searchTextField.delegate = self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mask = maskView()
    }

    private func maskView() -> UIView {
        let edgeInsets = UIEdgeInsets(
            top: Constants.topInset,
            left: Constants.leftInset,
            bottom: Constants.bottomInset,
            right: Constants.rightInset
        )
        let rect = bounds.inset(by: edgeInsets)
        let maskView = UIView(frame: rect)
        maskView.isUserInteractionEnabled = false
        maskView.backgroundColor = .black
        maskView.layer.cornerRadius = bounds.midY - Constants.topInset
        return maskView
    }

    func configure(with style: SearchStyle.SearchBarStyle) {
        self.style = style
        searchTextField.keyboardType = .default
        updateStyle()
    }

    private func updateStyle() {
        styleSearchIcon()
        styleClearIcon()
        styleSearchTextField()
        searchBarStyle = .minimal
        isTranslucent = true
        keyboardAppearance = .dark

        searchTextField.textColor = style.textColor
        searchTextField.font = style.font(for: traitCollection)
        searchTextField.tintColor = style.tintColor
        searchTextField.accessibilityIdentifier = style.accessibilityIdentifier
        searchTextField.borderStyle = .none

        placeholder = isSearchActive ? nil : localizedPlaceholderText
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.placeholderFont(for: traitCollection),
            .foregroundColor: style.placeholderTextColor
        ]
        searchTextField.attributedPlaceholder = NSAttributedString(string: localizedPlaceholderText ?? "", attributes: attributes)
    }

    private func styleSearchIcon() {
        let resizedSearchIcon = style.resizeIcon(
            searchIcon,
            into: style.searchIconSize(for: traitCollection)
        )
        self.setImage(
            resizedSearchIcon,
            for: .search,
            state: .normal
        )
        let horizontalOffset = style.searchIconHorizontalOffset(for: traitCollection)
        setPositionAdjustment(UIOffset(horizontal: horizontalOffset, vertical: .zero), for: .search)
    }

    private func styleSearchTextField() {
        backgroundColor = style.backgroundColor
        tintColor = .white
    }

    private func styleClearIcon() {
        setImage(clearIcon, for: .clear, state: .normal)
    }

    private func endSearch() {
        isSearchActive = false
        updateStyle()
        searchDelegate?.didEndSearch()
    }
}

extension SearchBar: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchActive = true
        updateStyle()
        searchDelegate?.didBeginEditing()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: SearchConstants.searchDebounceTimeInSeconds, repeats: false) { [weak self] _ in
            self?.searchDelegate?.didBeginSearch(for: searchText, type: .typing)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchDelegate?.didBeginSearch(for: text, type: .button)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        endSearch()
    }
}

extension SearchBar: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return !string.containsEmoji
    }
}

extension SearchBar {
    private enum Constants {
        static let leftInset: CGFloat = 8.0
        static let topInset: CGFloat = 8.0
        static let rightInset: CGFloat = 6.0
        static let bottomInset: CGFloat = 8.0
    }
}
