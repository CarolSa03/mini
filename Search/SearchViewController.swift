// swiftlint:disable file_length
import ActionsMenuApi
import AppReportingApi
import AppSettings_Api
import Combine
import Core_Images_Api
import Core_Ui_Api
import Extensions
import Impressions_Api
import Legacy_Api
import PCLSLabelsApi
import PeacockClientSDKApi
import PlayerNotificationsApi
import TilesKitApi
import TilesKitUi
import UIKit

final class SearchViewController: GSTMobileBaseViewController { // swiftlint:disable:this type_body_length
    // MARK: Consts

    private enum Constants {
        static let searchBarStackViewHeight: CGFloat = 60

        static func searchBarLeading(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 24 : 8
        }

        static func searchBarTrailing(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 26 : 8
        }

        static func searchBarTop(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 20 : 12
        }

        static func searchBarBottom(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 20 : 2
        }

        static func searchBarStackViewSpacing(for traitCollection: UITraitCollection) -> CGFloat {
            return traitCollection.isRegularRegular ? 38 : 20
        }

        static let horizontalSpacing: CGFloat = UIDevice.isPad ? 32 : 33
        static let innerSpacing: CGFloat = 24
        static let tabViewHeight: CGFloat = 54
        static let cancelButtonFontSize: CGFloat = 14
        static let cancelButtonTrailing: CGFloat = 20
        static let numberOfSections: Int = 1
        static let failedLoadingLabelLeadingTrailing: CGFloat = 20
        static let compactNumberOfColumns: Int = 1
        static let regularRegularLandscapeNumberOfColumns: Int = 3
        static let regularRegularPortraitNumberOfColumns: Int = 2

        static let metadataMaxCharacters = 60
    }

    // MARK: Views

    private lazy var searchBarStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.heightAnchor.constraint(equalToConstant: Constants.searchBarStackViewHeight).isActive = true
        return stackView
    }()

    private lazy var searchBar: SearchBar = {
        let searchBar = SearchBar(frame: .zero)
        searchBar.accessibilityIdentifier = AutomationConstants.Search.searchBar
        searchBar.searchTextField.accessibilityIdentifier = AutomationConstants.Search.searchField
        return searchBar
    }()

    private let cancelContainerView: UIView = UIView()

    private lazy var cancelButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(LocalizationKeys.Search.Cancel.localizedString, for: .normal)
        button.titleLabel?.font = Theme.shared.regularFont(size: Constants.cancelButtonFontSize)
        button.addAction(.init(handler: { [weak self] _ in
            self?.didTapCancelButton()
        }), for: .touchUpInside)
        return button
    }()

    private lazy var resultsContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var recentSearchesCollectionView: UICollectionView = {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: RecentSearchesCollectionViewFlowLayout()
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private lazy var searchResultsTabViewContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    private var searchBarLeadingConstraint: NSLayoutConstraint?
    private var searchBarTrailingConstraint: NSLayoutConstraint?
    private var searchBarTopConstraint: NSLayoutConstraint?
    private var searchBarBottomConstraint: NSLayoutConstraint?

    // MARK: Properties

    private weak var navigationDelegate: MainNavigationDelegate?
    private var style: SearchStyle = SearchStyle.defaultStyle()
    private let features: Features
    private let labels: Labels
    private let imageLoader: ImageLoader

    private let passThroughViewTag = 999
    private let recentSearchesCollectionViewFlowLayout = RecentSearchesCollectionViewFlowLayout()
    private let fullScreenloadingSpinnerConfiguration = LoadingSpinnerViewConfiguration(backgroundColor: Theme.Seamless.backgroundColor)

    private var isInitialLoad = true

    private var loadingSpinnerViews = [LoadingSpinnerView]()

    private lazy var searchResultsTabViewController: TabListViewController = {
        let isKidsProfile = viewModel.personaType == .kid
        let tabVC = TabListViewController(
            delegate: self,
            isKidsProfile: isKidsProfile,
            features: features
        )
        tabVC.overlayProvider = self
        return tabVC
    }()

    private var trimmedSearchTerm: String? {
        return searchBar.text?.trim()
    }

    override var shouldShowMainNavigationBar: Bool {
        return true
    }

    override var screenType: Screen {
        return .search
    }

    weak var overlayProvider: ImpressionsCollectorOverlayProvider?
    private var viewModel: SearchViewModelProtocol
    private let tilesFactory: SearchTilesFactory

    private var actionSheet: GSTMobileActionSheetViewController?

    init(
        viewModel: SearchViewModelProtocol,
        navigationDelegate: MainNavigationDelegate?,
        features: Features,
        labels: Labels,
        imageLoader: ImageLoader,
        tilesFactory: SearchTilesFactory
    ) {
        self.viewModel = viewModel
        self.navigationDelegate = navigationDelegate
        self.features = features
        self.labels = labels
        self.imageLoader = imageLoader
        self.tilesFactory = tilesFactory
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()

        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        view.backgroundColor = style.searchViewControllerStyle.backgroundColor

        configureSearchBar(with: style.searchBarStyle)

        addViewController(searchResultsTabViewController, toView: searchResultsTabViewContainer, applyingDefaultConstraints: false)
        searchResultsTabViewContainer.addConstraintsToPinEdges(subview: searchResultsTabViewController.view, toSafeArea: false)
        searchResultsTabViewContainer.isHidden = true

        configureRecentSearchesCollectionView()

        setupListeners()
        viewModel.setup()
        didChangeToIdle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.handleAppearance()
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.viewModel.trackOpen()
        beginEditingIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.handleDisappearance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.trackExit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentSizeClasses(from: previousTraitCollection) {
            updateLayout(for: traitCollection)
        }
    }

    private func beginEditingIfNeeded(factorInSearchBarText: Bool = true) {
        if UIAccessibility.isVoiceOverRunning {
            if searchResultsTabViewContainer.isHidden ||
                (factorInSearchBarText && (searchBar.text?.isEmpty ?? true)) {
                didStartTyping()
                searchBar.becomeFocusedElement()
            } else {
                searchResultsTabViewController.focusLastSelectedTab()
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func setupListeners() {
        viewModel.outputEvents.presentEmptySearch = { [weak self] resultsTab, contentFormat, shouldRefresh in
            self?.presentEmptySearchRail(
                resultsTab: resultsTab,
                contentFormat: contentFormat,
                shouldRefresh: shouldRefresh
            )
        }

        viewModel.outputEvents.presentInputEnded = { [weak self] in
            self?.didEndTyping()
        }

        viewModel.outputEvents.presentResults = { [weak self] results, contentFormat in
            self?.presentSearchResults(
                results: results,
                contentFormat: contentFormat
            )
        }

        viewModel.outputEvents.presentNoResultsPlaceholder = { [weak self] resultsTab, contentFormat in
            self?.presentNoResultsPlaceholder(
                resultsTab: resultsTab,
                contentFormat: contentFormat
            )
        }

        viewModel.outputEvents.routeToPdp = { [weak self] asset in
            self?.navigationDelegate?.navigate(to: .pdp(asset, nil, nil))
        }

        viewModel.outputEvents.routeToMiniPdp = { [weak self] railId, tileId, ctaSetHandler, analyticsDataSource in
            self?.navigationDelegate?.navigate(to: .miniPDP(
                railId: railId,
                tileId: tileId,
                miniPDPDataSourceType: .popularSearches,
                miniPlayersController: nil,
                ctaSetHandler: ctaSetHandler,
                analyticsDataSource: analyticsDataSource
            ))
        }

        viewModel.outputEvents.routeToGrid = { [weak self] asset in
            self?.navigationDelegate?.navigate(
                to: .collectionNavigation(
                    nil,
                    nil,
                    nil,
                    asset.nodeId,
                    asset.identifier,
                    asset.title,
                    nil,
                    nil,
                    nil,
                    false,
                    nil,
                    originTemplate: nil
                )
            )
        }

        viewModel.outputEvents.routeToCollection = { [weak self] asset in
            self?.navigationDelegate?.navigate(
                to: .collectionGroup(
                    asset,
                    asset.title,
                    nil,
                    originTemplate: nil
                )
            )
        }

        viewModel.outputEvents.routeToPlayer = { [weak self] asset in
            self?.navigationDelegate?.navigate(to: .player(asset, nil, nil, nil))
        }

        viewModel.outputEvents.routeToUpsellJourney = { [weak self] asset, contentSegments in
            self?.navigationDelegate?.navigate(to: .upsell(asset, contentSegments))
        }

        viewModel.outputEvents.routeToChannel = { [weak self] liveProgram in
            self?.navigationDelegate?.navigate(to: .channels(liveProgram, nil))
        }

        viewModel.outputEvents.displayFullScreenLoading = { [weak self] isLoading in
            self?.displayFullScreenLoading(isLoading)
        }

        viewModel.outputEvents.presentFailedResults = { [weak self] in
            self?.displayFailedLoadingError()
        }

        viewModel.outputEvents.numberOfItemsPerRow = { [weak self] in
            self?.numberOfItemsPerRow
        }

        viewModel.outputEvents.presentActionSheet = { [weak self] sheetOptions in
            self?.presentActionSheet(
                for: sheetOptions.asset,
                indexPath: sheetOptions.indexPath,
                actions: sheetOptions.actions
            )
        }

        viewModel.outputEvents.dismissActionSheet = { [weak self] completion in
            self?.actionSheet?.dismiss {
                completion()
            }
        }

        viewModel.outputEvents.animateMyStuffCTA = { [weak self] isInMyStuff, indexPath in
            let image = GSTMobileActionSheetImageProvider.image(
                for: .inclusionToggle,
                isInMyStuff: !isInMyStuff
            )

            let cell = self?.actionSheet?.tableView.cellForRow(at: indexPath) as? ChromecastDeviceTableViewCell
            if let image {
                cell?.animateMyStuffCTA(image: image)
            }
        }
    }

    private func setupViews() {
        view.addSubview(searchBarStackView)
        searchBarStackView.addArrangedSubview(searchBar)

        addSearchCancelCTAIfNeeded()

        view.addSubview(resultsContainerView)
        resultsContainerView.addSubviewAndPinEdges(recentSearchesCollectionView, toSafeArea: false)
        resultsContainerView.addSubviewAndPinEdges(searchResultsTabViewContainer, toSafeArea: false)

        let searchBarLeadingConstraint = searchBarStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let searchBarTrailingConstraint = searchBarStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let searchBarTopConstraint = searchBarStackView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor)
        let searchBarBottomConstraint = resultsContainerView.topAnchor.constraint(equalTo: searchBarStackView.bottomAnchor)

        NSLayoutConstraint.activate([
            searchBarLeadingConstraint,
            searchBarTrailingConstraint,
            searchBarTopConstraint,
            searchBarBottomConstraint,
            resultsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resultsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.searchBarLeadingConstraint = searchBarLeadingConstraint
        self.searchBarTrailingConstraint = searchBarTrailingConstraint
        self.searchBarTopConstraint = searchBarTopConstraint
        self.searchBarBottomConstraint = searchBarBottomConstraint

        updateLayout(for: traitCollection)
    }

    private func addSearchCancelCTAIfNeeded() {
        if features.isEnabled(.searchCancelCTA) {
            cancelContainerView.addSubview(cancelButton)
            cancelButton.leadingAnchor.constraint(equalTo: cancelContainerView.leadingAnchor).isActive = true
            cancelButton.topAnchor.constraint(equalTo: cancelContainerView.topAnchor).isActive = true
            cancelButton.bottomAnchor.constraint(equalTo: cancelContainerView.bottomAnchor).isActive = true
            cancelButton.trailingAnchor.constraint(equalTo: cancelContainerView.trailingAnchor, constant: -Constants.cancelButtonTrailing).isActive = true
            cancelContainerView.addSubviewAndPinEdges(cancelButton)
            searchBarStackView.addArrangedSubview(cancelContainerView)

            cancelContainerView.isHidden = true
        }
    }

    private func updateLayout(for traitCollection: UITraitCollection) {
        searchBarTrailingConstraint?.constant = -Constants.searchBarTrailing(for: traitCollection)
        searchBarLeadingConstraint?.constant = Constants.searchBarLeading(for: traitCollection)
        searchBarTopConstraint?.constant = Constants.searchBarTop(for: traitCollection)
        searchBarBottomConstraint?.constant = Constants.searchBarBottom(for: traitCollection)
        searchBarStackView.spacing = Constants.searchBarStackViewSpacing(for: traitCollection)
    }

    private func setupLoadingSpinnerViews(for tabs: [SearchTab]) {
        guard loadingSpinnerViews.isEmpty else { return }
        for _ in tabs {
            loadingSpinnerViews.append(createLoadingSpinnerView())
        }
    }

    private func createLoadingSpinnerView() -> LoadingSpinnerView {
        let loadingSpinnerView = LoadingSpinnerView()
        loadingSpinnerView.backgroundColor = style.searchViewControllerStyle.loadingSpinnerConfiguration.backgroundColor
        loadingSpinnerView.adjustsSizeForKeyboard = true
        loadingSpinnerView.isUserInteractionEnabled = true
        return loadingSpinnerView
    }

    private func configureSearchBar(with style: SearchStyle.SearchBarStyle) {
        let isKidsProfile = viewModel.personaType == .kid

        searchBar.localizedPlaceholderText = isKidsProfile
        ? LocalizationKeys.Search.PlaceholderKids.localizedString
        : LocalizationKeys.Search.Placeholder.localizedString

        searchBar.configure(with: style)
        searchBar.searchDelegate = self
    }

    private func configureRecentSearchesCollectionView() {
        recentSearchesCollectionView.delegate = self
        recentSearchesCollectionView.dataSource = self
        recentSearchesCollectionView.setCollectionViewLayout(recentSearchesCollectionViewFlowLayout, animated: false)
        recentSearchesCollectionView.keyboardDismissMode = .onDrag
        recentSearchesCollectionView.registerCell(withType: RecentSearchesCollectionViewCell.self)
        recentSearchesCollectionView.registerSectionHeader(withType: SearchCollectionViewHeader.self)
        recentSearchesCollectionView.backgroundColor = style.searchViewControllerStyle.backgroundColor
        recentSearchesCollectionView.isHidden = true
    }

    override func dismissKeyboard(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        let hitView = view.hitTest(location, with: nil)
        if hitView?.tag == passThroughViewTag || hitView?.superview?.tag == passThroughViewTag { return }
        super.dismissKeyboard(recognizer: recognizer)
    }

    private func didChangeToIdle() {
        viewModel.switchTab(to: .emptySearch)
        searchResultsTabViewController.reloadData()
        viewModel.fetchPlaceholderCollection(contentFormat: .emptySearch, forceUpdate: false)
    }

    private func presentEmptySearchRail(
        resultsTab: SearchTab,
        contentFormat: SearchContentFormat,
        shouldRefresh: Bool
    ) {
        recentSearchesCollectionView.isHidden = true
        searchResultsTabViewContainer.isHidden = false

        var tabIndex = 0

        if let index = index(
            for: contentFormat,
            in: searchResultsTabViewController.tabPages
        ) {
            tabIndex = index
            searchResultsTabViewController.tabPages[tabIndex] = resultsTab
        } else {
            searchResultsTabViewController.tabPages = [resultsTab]
        }

        viewModel.switchTab(to: resultsTab.contentFormat)
        searchResultsTabViewController.reloadPage(
            at: tabIndex,
            with: resultsTab
        )
        searchResultsTabViewController.reloadData(
            at: tabIndex,
            shouldRefreshPages: shouldRefresh ? true : searchResultsTabViewController.tabPages != [resultsTab]
        )
        beginEditingIfNeeded(factorInSearchBarText: isInitialLoad)
        if isInitialLoad { isInitialLoad = false }
    }

    private func didStartTyping() {
        showSearchInput()

        if trimmedSearchTerm.isNilOrEmpty {
            searchResultsTabViewContainer.isHidden = true
            recentSearchesCollectionView.isHidden = false
            recentSearchesCollectionView.reloadData()
        } else {
            recentSearchesCollectionView.isHidden = true
        }
    }

    private func presentNoResultsPlaceholder(
        resultsTab: SearchTab,
        contentFormat: SearchContentFormat
    ) {
        recentSearchesCollectionView.isHidden = true
        searchResultsTabViewContainer.isHidden = false

        guard
            let index = index(
                for: contentFormat,
                in: searchResultsTabViewController.tabPages
            )
        else { return }

        let shouldRefreshPages = searchResultsTabViewController.tabPages[index] != resultsTab
        searchResultsTabViewController.tabPages[index] = resultsTab
        displayFullScreenLoading(false)

        searchResultsTabViewController.reloadPage(
            at: index,
            with: resultsTab
        )
        searchResultsTabViewController.reloadData(
            at: index,
            shouldRefreshPages: shouldRefreshPages
        )
    }

    private func presentSearchResults(
        results: SearchResults,
        contentFormat: SearchContentFormat
    ) {
        setupLoadingSpinnerViews(for: results.tabs)

        if trimmedSearchTerm.isNilOrEmpty {
            guard searchBar.isSearchActive else { return }
            recentSearchesCollectionView.isHidden = false
            searchResultsTabViewContainer.isHidden = true
            recentSearchesCollectionView.reloadData()
        } else {
            searchResultsTabViewController.tabPages = results.tabs
            recentSearchesCollectionView.isHidden = true
            searchResultsTabViewContainer.isHidden = false
            let index = index(
                for: contentFormat,
                in: searchResultsTabViewController.tabPages
            )

            guard
                let index,
                let tab = searchResultsTabViewController.tabPages[safe: index]
            else {
                return
            }

            if viewModel.shouldFetchNoResultsPlaceholderCollection(searchTab: tab) {
                viewModel.fetchPlaceholderCollection(contentFormat: contentFormat, forceUpdate: false)
                return
            }

            for (index, tab) in searchResultsTabViewController.tabPages.enumerated() {
                searchResultsTabViewController.reloadPage(
                    at: index,
                    with: tab
                )
            }

            searchResultsTabViewController.reloadData(
                at: index,
                shouldRefreshPages: false
            )
        }
    }

    private func didEndTyping() {
        hideSearchInput()

        if trimmedSearchTerm.isNilOrEmpty {
            recentSearchesCollectionView.isHidden = true
            searchResultsTabViewContainer.isHidden = true
            didChangeToIdle()
        } else {
            searchResultsTabViewContainer.isHidden = false
            searchResultsTabViewController.focusLastSelectedTab()
        }
    }

    private func showSearchInput() {
        cancelContainerView.isHidden = false
        searchBar.becomeFirstResponder()
    }

    private func hideSearchInput() {
        cancelContainerView.isHidden = true
        searchBar.resignFirstResponder()
    }

    private func displayFullScreenLoading(_ loading: Bool) {
        if loading {
            presentFullScreenLoadingSpinner()
        } else {
            dismissFullScreenLoadingSpinner()
        }
    }

    private func presentFullScreenLoadingSpinner() {
        LoadingSpinnerView.presentLoadingSpinner(on: view, configuration: fullScreenloadingSpinnerConfiguration)
    }

    private func dismissFullScreenLoadingSpinner() {
        LoadingSpinnerView.dismissLoadingSpinner(on: view)
    }

    private func displayFailedLoadingError() {
        InAppNotificationServiceImpl.shared.notify(type: .error(style.searchViewControllerStyle.failedLoadingErrorMessage))
    }

    private func index(
        for contentFormat: SearchContentFormat,
        in tabPages: [SearchTab]
    ) -> Int? {
        return tabPages.find { tab -> Bool in
            contentFormat == tab.contentFormat
        }
    }

    private func didTapCancelButton() {
        viewModel.trackCancel(
            term: searchBar.text,
            areResultsVisible: !searchResultsTabViewContainer.isHidden
        )
        searchBar.text = nil
        hideSearchInput()
    }

    private func presentActionSheet(
        for asset: Legacy_Api.Asset,
        indexPath: IndexPath,
        actions: [Action]
    ) {
        let title = asset.title
        var metaDataItems: [ActionsMenuApi.MetadataItem] = []
        var synopsis: String?
        var episodeTitle: String?
        var metaDataOptions: ActionsMenuApi.AssetMetadataOptionSet = .allInfo

        switch asset {
        case let programme as Legacy_Api.Programme:
            synopsis = programme.synopsisShort
        case let episode as Legacy_Api.Episode:
            synopsis = episode.synopsisLong
            episodeTitle = episode.episodeTitleOverride
            metaDataOptions = .downloadsOptions
        case let series as Legacy_Api.Series:
            synopsis = series.synopsisShort
        default:
            break
        }

        metaDataItems = viewModel.createAssetMetadataItems(
            with: asset,
            options: metaDataOptions,
            maxCharacters: Constants.metadataMaxCharacters
        )

        actionSheet = GSTMobileActionSheetViewController(
            withHeaderTitle: title,
            episodeTitle: episodeTitle,
            metadataItems: metaDataItems,
            synopsis: synopsis,
            labels: labels,
            features: features,
            viewModel: CTAMobileActionSheetViewModel(),
            actionSheetType: .collectionGroup,
            imageLoader: imageLoader
        )

        self.actionSheet?.setActions(actions, animated: false)
        self.actionSheet?.show()
    }
}

extension SearchViewController: UICollectionViewDelegate, UICollectionViewDataSource, UIScrollViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        let recentSearches = viewModel.getRecentSearches()
        return recentSearches.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let recentSearches = viewModel.getRecentSearches()
        let cell = collectionView.dequeueReusableCell(ofType: RecentSearchesCollectionViewCell.self, for: indexPath)
        let title = recentSearches[indexPath.row]

        cell.configure(with: title)
        cell.accessibilityIdentifier = "recentSearchesCell-\(indexPath.row)"
        cell.tag = passThroughViewTag
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSectionHeader(ofType: SearchCollectionViewHeader.self, for: indexPath)
            return headerView
        default:
            preconditionFailure("Not handled")
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let recentSearches = viewModel.getRecentSearches()
        let searchTerm = recentSearches[indexPath.item]
        searchBar.text = searchTerm
        let tabIndex = searchResultsTabViewController.index
        var contentFormat = searchResultsTabViewController.tabPages[safe: tabIndex]?.contentFormat ?? .longform
        if contentFormat == .emptySearch {
            contentFormat = .longform
        }
        viewModel.search(
            for: searchTerm,
            contentFormat: contentFormat,
            type: .list
        )
    }
}

extension SearchViewController: SearchBarViewDelegate {
    func didBeginEditing() {
        didStartTyping()
    }

    func didBeginSearch(
        for text: String?,
        type: SearchType
    ) {
        var contentFormat: SearchContentFormat = searchResultsTabViewController.tabPages[
            safe: searchResultsTabViewController.index
        ]?.contentFormat ?? .longform

        let searchTerm = trimmedSearchTerm

        if
            let searchTerm,
            !searchTerm.isEmpty,
            contentFormat == .emptySearch
        {
            contentFormat = .longform
        }

        viewModel.search(
            for: searchTerm,
            contentFormat: contentFormat,
            type: type
        )
    }

    func didEndSearch() {
        didEndTyping()
    }
}

extension SearchViewController: TabListViewControllerDelegate {
    func cell(
        for item: TileViewModel,
        at indexPath: IndexPath,
        collectionView: UICollectionView
    ) -> UICollectionViewCell {
        return tilesFactory.cell(
            for: item,
            at: indexPath,
            collectionView: collectionView
        )
    }

    func resolve(tile tileId: String, railId: String?) -> TileViewModel {
        let contentFormat: SearchContentFormat = searchResultsTabViewController.tabPages[
            safe: searchResultsTabViewController.index
        ]?.contentFormat ?? .emptySearch

        return viewModel.resolve(
            tileId: tileId,
            contentFormat: contentFormat
        )
    }

    func fetch(tiles tileIds: [TileID]) {
        viewModel.fetch(tiles: tileIds)
    }

    func cancelFetchingIfPossible(tiles tileIds: [TileID]) {
        viewModel.cancelFetchingIfPossible(tiles: tileIds)
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    func layout(
        with title: String?,
        isScrollable: Bool,
        isLandscape: Bool,
        tileCount: Int,
        forSectionAt sectionIndex: Int,
        environment: any NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection? {
        let numberOfItems = tileCount
        let sectionInset: CGFloat
        let interGroupSpacing: CGFloat
        let interItemSpacing: CGFloat

        if features.isEnabled(.searchPortraitTileRatio) {
            if environment.traitCollection.isRegularRegular {
                interGroupSpacing = CollectionGridHelpers.ThreeByFour.tabletInterLineSpacing
                interItemSpacing = CollectionGridHelpers.ThreeByFour.tabletItemSpacing
                sectionInset = isWider
                    ? CollectionGridHelpers.ThreeByFour.tabletLandscapeInset
                    : CollectionGridHelpers.ThreeByFour.tabletPortraitInset
            } else {
                sectionInset = CollectionGridHelpers.ThreeByFour.phoneInset
                interGroupSpacing = CollectionGridHelpers.ThreeByFour.phoneInterLineSpacing
                interItemSpacing = CollectionGridHelpers.ThreeByFour.phoneItemSpacing
            }
        } else {
            if environment.traitCollection.isRegularRegular {
                interGroupSpacing = CollectionGridHelpers.SixteenByNine.tabletInterLineSpacing
                interItemSpacing = CollectionGridHelpers.SixteenByNine.tabletItemSpacing
                sectionInset = isWider
                    ? CollectionGridHelpers.SixteenByNine.tabletLandscapeInset
                    : CollectionGridHelpers.SixteenByNine.tabletPortraitInset
            } else {
                sectionInset = CollectionGridHelpers.SixteenByNine.phoneInset
                interGroupSpacing = CollectionGridHelpers.SixteenByNine.phoneInterLineSpacing
                interItemSpacing = CollectionGridHelpers.SixteenByNine.phoneItemSpacing
            }
        }

        let marginsWidth = (sectionInset * 2) + (interItemSpacing * (CGFloat(numberOfItemsPerRow) - 1))
        let itemWidth = (environment.container.contentSize.width - marginsWidth) / CGFloat(numberOfItemsPerRow)
        let itemHeight = itemWidth / aspectRatio
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth.rounded(.down)),
            heightDimension: .estimated(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupHeight: NSCollectionLayoutDimension

        if features.isEnabled(.searchPortraitTileRatio) {
            let tuneInBadgeHeight = getPortraitTuneInBadgeHeight(environment)
            groupHeight = .absolute(itemHeight + tuneInBadgeHeight)
        } else {
            groupHeight = .estimated(itemHeight)
        }

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: groupHeight
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: Array(
                repeating: item,
                count: max(1, numberOfItems)
            )
        )

        group.interItemSpacing = .fixed(interItemSpacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = interGroupSpacing

        section.contentInsets = NSDirectionalEdgeInsets(
            top: sectionInset,
            leading: sectionInset,
            bottom: .zero,
            trailing: sectionInset
        )

        if viewModel.noSearchResults {
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(getHeightForNoResultsHeader(environment))
            )

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .topLeading
            )

            section.boundarySupplementaryItems = [header]
        }

        return section
    }

    func configTabCell(_ cell: UICollectionViewCell, forTabPage tabPage: SearchTab) {
        guard let tabCell = cell as? SearchResultTabViewCell else { return }

        tabCell.configureWith(
            tabTitle: tabPage.name,
            style: style.resultsTabHeaderStyle,
            format: tabPage.contentFormat
        )

        tabCell.tag = passThroughViewTag
    }

    func configureViewForSectionHeader(
        _ reusableView: UICollectionReusableView,
        forIndexPath indexPath: IndexPath,
        forTabPage tabPage: SearchTab
    ) {
        reusableView.subviews.forEach({ $0.removeFromSuperview() })

        guard tabPage.searchNoResultsReason == .noMatch else { return }

        let messageView = NoResultsCollectionLabelView()
        messageView.frame = reusableView.bounds
        reusableView.addSubviewAndPinEdges(messageView)

        if features.isEnabled(.searchNoResultsContent) {
            messageView.configure(with: style.searchViewControllerStyle.noResultsLabel)
        } else {
            messageView.configure(with: style.searchViewControllerStyle.noContentLabel)
        }
    }

    func tabPageScrollViewWillBeginDragging(
        _ scrollView: UIScrollView,
        on tabPage: SearchTab
    ) {
        hideSearchInput()
    }

    func didSelectItemAt(
        _ indexPath: IndexPath,
        item: TileViewModel
    ) {
        viewModel.didSelect(tile: item, index: indexPath.item)
    }

    func didSelect(tab: SearchTab) {
        viewModel.didSelectTab(for: searchBar.text, contentFormat: tab.contentFormat, type: .tab)

        if viewModel.shouldFetchNoResultsPlaceholderCollection(searchTab: tab) {
            viewModel.fetchPlaceholderCollection(contentFormat: tab.contentFormat, forceUpdate: false)
        }
    }

    func loadingSpinnerView(forTabPage tabPage: SearchTab) -> LoadingSpinnerView? {
        let index = index(
            for: tabPage.contentFormat,
            in: searchResultsTabViewController.tabPages
        )

        guard
            let index,
            tabPage.isLoading
        else {
            return nil
        }

        return loadingSpinnerViews[safe: index]
    }

    var tilesDidChange: AnyPublisher<TilesKitApi.TileUpdates<TileID>, Never> {
        viewModel.tilesDidChange
    }

    func configureCell(
        _ collectionView: UICollectionView,
        forIndexPath indexPath: IndexPath,
        forTabPage tabPage: SearchTab
    ) -> UICollectionViewCell {
        return UICollectionViewCell()
    }

    func collectionViewLayoutFor(tabPage: SearchTab) -> UICollectionViewLayout {
        return UICollectionViewLayout()
    }

    func fallbackCell(at indexPath: IndexPath, collectionView: UICollectionView) -> UICollectionViewCell {
        return UICollectionViewCell()
    }

    func collectionCellTypeFor(tabPage: SearchTab) -> [UICollectionViewCell.Type] {
        return []
    }

    func numberOfItemsInSection(_ section: Int, forTabPage tabPage: SearchTab) -> Int {
        return tabPage.items.count
    }

    func isLoading(forTabPage tabPage: SearchTab) -> Bool {
        return tabPage.isLoading
    }

    var tabsHorizontalSpacing: CGFloat {
        return Constants.horizontalSpacing
    }

    var tabsInnerSpacing: CGFloat {
        return Constants.innerSpacing
    }

    var tabViewHeight: CGFloat {
        return Constants.tabViewHeight
    }

    var collectionCellTypeForTabs: UICollectionViewCell.Type {
        return SearchResultTabViewCell.self
    }

    func shouldHideTabs() -> Bool {
        return viewModel.shouldHideTabs()
    }

    func collectionSectionHeaderTypeFor(tabPage: SearchTab) -> UICollectionReusableView.Type? {
        return UICollectionReusableView.self
    }

    func numberOfSectionsFor(tabPage: SearchTab) -> Int {
        return Constants.numberOfSections
    }

    func emptyCollectionTextMessage(forTabPage tabPage: SearchTab) -> NoContentLabelStyle? {
        return nil
    }

    func tabPagePreFetching() {}

    func willTransition(to index: Int, forTabPage tabPage: SearchTab) {}
}

extension SearchViewController: PlayerNotificationDelegate {
    func handleMaturityRatingExceededNotification(for asset: Legacy_Api.Asset?) {
        viewModel.trackExceededMaturityRating(for: asset)
    }
}

extension SearchViewController: ImpressionsCollectorOverlayProvider {
    var overlayFrames: [CGRect] {
        return (overlayProvider?.overlayFrames ?? []).map { frame in
            return view.convert(
                frame,
                to: searchResultsTabViewContainer
            )
        }
    }
}

extension SearchViewController: ImpressionsCollectorOverlayable {}

private extension SearchViewController {
    var numberOfItemsPerRow: Int {
        if features.isEnabled(.searchPortraitTileRatio) {
            if traitCollection.isRegularRegular {
                return isWider
                    ? CollectionGridHelpers.ThreeByFour.tabletLandscapeNumberOfColumns
                    : CollectionGridHelpers.ThreeByFour.tabletPortraitNumberOfColumns
            } else {
                return CollectionGridHelpers.ThreeByFour.phoneNumberOfColumns
            }
        } else {
            if traitCollection.isRegularRegular {
                return isWider
                    ? CollectionGridHelpers.SixteenByNine.tabletLandscapeNumberOfColumns
                    : CollectionGridHelpers.SixteenByNine.tabletPortraitNumberOfColumns
            } else {
                return CollectionGridHelpers.SixteenByNine.phoneNumberOfColumns
            }
        }
    }

    var aspectRatio: CGFloat {
        return features.isEnabled(.searchPortraitTileRatio)
            ? CollectionGridHelpers.ThreeByFour.aspectRatio
            : CollectionGridHelpers.SixteenByNine.aspectRatio
    }

    func getPortraitTuneInBadgeHeight(_ environment: NSCollectionLayoutEnvironment) -> CGFloat {
        let height = environment.traitCollection.isRegularRegular ?
            CollectionGridHelpers.ThreeByFour.tuneInBadgeHeightRR :
            CollectionGridHelpers.ThreeByFour.tuneInBadgeHeight

        return height + CollectionGridHelpers.ThreeByFour.extraSpacing
    }

    func getHeightForNoResultsHeader(_ environment: NSCollectionLayoutEnvironment) -> CGFloat {
        return environment.traitCollection.isRegularRegular ? 120 : 160
    }
}
