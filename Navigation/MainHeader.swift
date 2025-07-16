// swiftlint:disable file_length
import AppLogoApi
import ChromecastUi
import Combine
import CombineSchedulers
import ConcurrencyApi
import Core_Accessibility_Api
import Core_Common_Api
import DIManagerSwift
import Extensions
import MainHeaderUi
import PCLSLabelsApi
import PersonasApi
import Profile_Api
import UIKit

public final class MainHeader: UIStackView, MainHeaderProtocol {

    public weak var delegate: MainHeaderDelegate?
    private var persona: Persona? {
        didSet {
            if let profileButton = profileButton as? ProfileButton {
                profileButton.configure(
                    with: persona?.avatar,
                    isKidsProfile: self.isKidsProfile
                )
            }
        }
    }
    private let getAppLogoUseCase: any GetAppLogoUseCase
    private var isKidsProfile: Bool { persona?.type == .kid }
    private var context: Context
    private var buttonSet: ButtonOptions
    private let labels: Labels
    private let observeCurrentPersonaUseCase: any ObserveCurrentPersonaUseCase
    private let observeLabelsUpdateUseCase: any ObserveLabelsUpdateUseCase
    private let mainScheduler: AnySchedulerOf<DispatchQueue>
    private let chromecastButtonProvider: Provider<ChromecastButton>
    private var cancellables = Set<AnyCancellable>()
    private var previousWidth: CGFloat = 0

    private var logoType: AppLogo.LogoType {
        switch context {
        case .´default´:
            if isKidsProfile {
                return .kids
            }
            return .browse
        case .whosWatching:
            return .browse
        }
    }

    private lazy var peacockLogo: AppLogo? = getAppLogoUseCase.execute(input: logoType)

    // MARK: - Views
    public private(set) var profileButton: UIControl?
    private var chromecastButton: ChromecastButton?

    private lazy var logoContainerView: UIView = makeLogoView()
    private lazy var logoImageView: LogoImageView = makePeacockLogo()
    private lazy var accountButton: GSTMobileButton = makeMyAccountButton()
    private lazy var auxiliaryView: UIView = makeAuxiliaryView()
    private lazy var headerButtonsStack: UIStackView = makeHeaderButtonsStackView()

    // MARK: - Constraints 📐
    private var profileButtonWidthConstraint: NSLayoutConstraint?
    private var profileButtonHeightConstraint: NSLayoutConstraint?
    private var chromecastButtonWidthConstraint: NSLayoutConstraint?
    private var chromecastButtonHeightConstraint: NSLayoutConstraint?
    private var logoImageWidthConstraint: NSLayoutConstraint?

    public init(
        for persona: Persona? = nil,
        context: Context = .´default´,
        buttonSet: ButtonOptions = [],
        getAppLogoUseCase: any GetAppLogoUseCase,
        labels: Labels,
        observeCurrentPersonaUseCase: any ObserveCurrentPersonaUseCase,
        observeLabelsUpdateUseCase: any ObserveLabelsUpdateUseCase,
        mainScheduler: AnySchedulerOf<DispatchQueue>,
        chromecastButtonProvider: Provider<ChromecastButton>
    ) {
        self.persona = persona
        self.context = context
        self.buttonSet = buttonSet
        self.getAppLogoUseCase = getAppLogoUseCase
        self.labels = labels
        self.observeCurrentPersonaUseCase = observeCurrentPersonaUseCase
        self.observeLabelsUpdateUseCase = observeLabelsUpdateUseCase
        self.mainScheduler = mainScheduler
        self.chromecastButtonProvider = chromecastButtonProvider
        super.init(frame: .zero)

        setup(with: buttonSet)
        updateLayout()
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentSizeClasses(from: previousTraitCollection) {
            updateLayout()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        if previousWidth != frame.width {
            previousWidth = frame.width
            updateLayout()
        }
    }

    public func setAuxiliaryView(view: UIView) {
        auxiliaryView.subviews.forEach { $0.removeFromSuperview() }
        auxiliaryView.addSubviewAndPinEdges(view)
    }

    // swiftlint:disable:next function_body_length
    public func setupAccessibility(
        with imageLabel: String,
        tabAccessibilityElement: AccessibilityObject?
    ) {
        var elements: [AccessibilityObject] = [
            .imageView(
                logoImageView,
                .init(
                    label: imageLabel,
                    traits: .image
                )
            )
        ]

        if let tabAccessibilityElement = tabAccessibilityElement {
            elements.append(tabAccessibilityElement)
        }

        if let chromecastButton = chromecastButton,
           buttonSet.contains(.chromecast) {
            elements.append(
                .button(
                    chromecastButton,
                    .init(
                        isElement: !chromecastButton.isHidden,
                        label: labels.getLabel(
                            forKey: LocalizationKeys.Accessibility.Chromecast.title
                        )
                    )
                )
            )
        }

        if let profileButton = profileButton,
           buttonSet.contains(.profile) {
            elements.append(
                .view(
                    profileButton,
                    .init(
                        label: labels.getLabel(
                            forKey: LocalizationKeys.Accessibility.Generic.profile
                        ),
                        value: persona?.displayName,
                        traits: .button
                    )
                )
            )
        }

        if buttonSet.contains(.myAccount) {
            elements.append(
                .button(
                    accountButton,
                    .init(
                        traits: .header
                    )
                )
            )
        }

        configureAccessibilityElements(with: elements)
    }

    public func hideAccountButton() {
        accountButton.isHidden = true
    }

    public func verticalSpacingForButtons() -> CGFloat {
        return traitCollection.isRegularRegular ? Constants.verticalButtonSpacingRR : Constants.verticalButtonSpacing
    }

    public func addButtons(_ newButtonSet: ButtonOptions) {
        let dijointButtons = newButtonSet.subtracting(self.buttonSet)

        guard !dijointButtons.isEmpty else { return }
        if headerButtonsStack.arrangedSubviews.isEmpty && headerButtonsStack.superview == nil {
            configureButtonsInContainer(with: dijointButtons, container: headerButtonsStack)
        } else {
            let buttons = makeButtonViews(for: dijointButtons)
            buttons.forEach { headerButtonsStack.addArrangedSubview($0) }
        }
        buttonSet.formUnion(dijointButtons)
    }

    // MARK: - Actions
    private func didTapAccountButton() {
        delegate?.didTapAccountButton()
    }

    @objc
    private func handleLogoTap(_ sender: UITapGestureRecognizer) {
        delegate?.didTapLogo()
    }
}

// MARK: - View Setup / Layout updates
private extension MainHeader {

    private func setup(with buttonSet: ButtonOptions) {
        alignment = .center
        spacing = itemSpacing()
        isLayoutMarginsRelativeArrangement = true

        [logoContainerView, auxiliaryView].forEach {
            addArrangedSubview($0)
        }

        if !buttonSet.isEmpty {
            configureButtonsInContainer(with: buttonSet, container: headerButtonsStack)
        }

        logoImageWidthConstraint = logoContainerView.widthAnchor.constraint(lessThanOrEqualToConstant: maxLogoWidth())
        logoImageWidthConstraint?.isActive = true

        NSLayoutConstraint.activate([
            auxiliaryView.heightAnchor.constraint(equalTo: heightAnchor),
            logoContainerView.heightAnchor.constraint(equalToConstant: Constants.logoHeight)
        ])
    }

    private func configureButtonsInContainer(with buttonSet: ButtonOptions, container: UIStackView) {
        let buttons = makeButtonViews(for: buttonSet)
        buttons.forEach { container.addArrangedSubview($0) }
        setCustomSpacing(Constants.headerButtonsSpacing, after: auxiliaryView)
        addArrangedSubview(container)
    }

    private func updateLayout() {
        spacing = itemSpacing()
        layoutMargins = layoutMargins()
        updateLogoConstraints()
        updatePeacockLogo()
        updateButtonsConstraints()
    }

    private func updateButtonsConstraints() {
        let buttonSize = peacockHeaderButtonSize()
        profileButtonWidthConstraint?.constant = buttonSize.width
        profileButtonHeightConstraint?.constant = buttonSize.height
        chromecastButtonWidthConstraint?.constant = buttonSize.width
        chromecastButtonHeightConstraint?.constant = buttonSize.height
    }

    private func updateLogoConstraints() {
        logoImageWidthConstraint?.isActive = false
        logoImageWidthConstraint = logoContainerView.widthAnchor.constraint(lessThanOrEqualToConstant: maxLogoWidth())
        logoImageWidthConstraint?.isActive = true
    }

    private func updatePeacockLogo() {
        logoImageView.setImage(
            logoUrl: peacockLogo?.appropriateStringUrl(isRegularRegular: traitCollection.isRegularRegular),
            onFailureImage: peacockLogo?.appropriateFallback(isRegularRegular: traitCollection.isRegularRegular),
            height: Constants.logoHeight,
            maxWidth: maxLogoWidth(),
            animateTransition: false
        )
    }
}

// MARK: Helper functions
private extension MainHeader {
    private func makeButtonViews(for set: ButtonOptions) -> [UIView] {
        var views = [UIView]()

        if set.contains(.chromecast) {
            let button = chromecastButtonProvider.make()
            button.translatesAutoresizingMaskIntoConstraints = false
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            let buttonSize = peacockHeaderButtonSize()
            chromecastButtonWidthConstraint = view.widthAnchor.constraint(equalToConstant: buttonSize.width)
            chromecastButtonHeightConstraint = view.heightAnchor.constraint(equalToConstant: buttonSize.height)
            chromecastButtonWidthConstraint?.isActive = true
            chromecastButtonHeightConstraint?.isActive = true
            view.addSubviewAndPinEdges(button)
            views.append(view)
            chromecastButton = button
        }

        if set.contains(.profile) {
            let button = makeProfileButton()
            views.append(button)
            profileButton = button

            observeCurrentPersonaUseCase
                .execute()
                .receive(on: mainScheduler)
                .sink(
                    receiveCompletion: { _ in /* Do nothing */ },
                    receiveValue: { persona in
                        self.persona = persona.patch()
                    }
                )
                .store(in: &cancellables)
        }

        if set.contains(.myAccount) {
            views.append(accountButton)
            observeLabelsUpdateUseCase.execute()
                .receive(on: mainScheduler)
                .sink(receiveValue: { [weak self] _ in
                    guard let self else { return }
                    self.accountButton.updateTitleAndAccessibilityLabel(
                        with: self.labels.getLabel(forKey: LocalizationKeys.MyAccount.myAccount)
                    )
                })
                .store(in: &cancellables)
        }

        return views
    }

    private func makeAuxiliaryView() -> UIView {
        let view = UIView()
        return view
    }

    private func makeProfileButton() -> UIControl {
        let button = ProfileButton()
        button.accessibilityIdentifier = AutomationConstants.HomePage.profileButton
        button.configure(
            with: persona?.avatar,
            isKidsProfile: isKidsProfile
        )
        button.action = { [weak self] in
            self?.delegate?.didTapProfileButton()
        }

        let buttonSize = peacockHeaderButtonSize()
        profileButtonWidthConstraint = button.widthAnchor.constraint(equalToConstant: buttonSize.width)
        profileButtonHeightConstraint = button.heightAnchor.constraint(equalToConstant: buttonSize.height)
        profileButtonWidthConstraint?.isActive = true
        profileButtonHeightConstraint?.isActive = true

        return button
    }

    private func makeHeaderButtonsStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = Constants.headerButtonsSpacing
        stackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return stackView
    }

    private func makeMyAccountButton() -> GSTMobileButton {
        let button = GSTMobileButton()
        button.configure(with: .init(titleColor: Theme.Profiles.ProfileSelection.AccountButton.textColor,
                                     backgroundColor: Theme.Profiles.ProfileSelection.AccountButton.backgroundColor,
                                     image: #imageLiteral(resourceName: "profiles_account_icon"),
                                     title: labels.getLabel(forKey: LocalizationKeys.MyAccount.myAccount),
                                     compactTitle: nil,
                                     accessibilityIdentifier: AutomationConstants.HomePage.myAccountButton),
                         style: .secondaryDark,
                         truncationBehaviour: .hidesTitle)
        button.addAction(.init(handler: { [weak self] _ in
            self?.didTapAccountButton()
        }), for: .touchUpInside)
        return button
    }

    private func makeLogoView() -> UIView {
        let logoContainerView = UIView()

        logoContainerView.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: logoContainerView.leadingAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: logoContainerView.trailingAnchor)
        ])

        return logoContainerView
    }

    private func makePeacockLogo() -> LogoImageView {
        let imageView = LogoImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.isUserInteractionEnabled = true
        imageView.isAccessibilityElement = true
        imageView.accessibilityIdentifier = AutomationConstants.SignIn.topBarLogo

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleLogoTap(_:)))
        imageView.addGestureRecognizer(tapGestureRecognizer)

        return imageView
    }
}

// MARK: Sizing and spacing functions
private extension MainHeader {
    private func itemSpacing() -> CGFloat {
        return traitCollection.isRegularRegular ? Constants.itemSpacingRR : Constants.itemSpacing
    }

    private func layoutMargins() -> UIEdgeInsets {
        let margin: CGFloat = traitCollection.isRegularRegular ? Constants.layoutMarginRR : Constants.layoutMargin
        return .init(top: .zero, left: margin, bottom: .zero, right: margin)
    }

    private func peacockHeaderButtonSize() -> CGSize {
        let size: CGFloat = Constants.navButtonSize
        return .init(width: size, height: size)
    }

    private func maxLogoWidth() -> CGFloat {
        if isKidsProfile {
            return LogoImageView.Constants.logoBrowseMaxWidthKids
        } else {
            return LogoImageView.Constants.logoBrowseMaxWidth
        }
    }
}

// MARK: Constants
private extension MainHeader {
    private struct Constants {
        static let headerButtonsSpacing: CGFloat = 8
        static let itemSpacing: CGFloat = 10
        static let itemSpacingRR: CGFloat = 20
        static let layoutMargin: CGFloat = 16
        static let layoutMarginRR: CGFloat = 32
        static let logoWidth: CGFloat = 120
        static let logoWidthKids: CGFloat = 200
        static let logoWidthRR: CGFloat = 110
        static let logoWidthRRWider: CGFloat = 150
        static let logoHeight: CGFloat = 32
        static let navButtonSize: CGFloat = 48
        static let verticalButtonSpacing: CGFloat = 4
        static let verticalButtonSpacingRR: CGFloat = 12
    }
}
