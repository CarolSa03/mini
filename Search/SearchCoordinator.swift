import Analytics
import AppSettings_Api
import ChannelsApi
import CombineSchedulers
import Core_Ui_Api
import Core_Ui_Ui
import Legacy_Api
import MiniPDPAPI
import PersonasApi
import PlayerContextApi
import PlayerNotificationsApi
import PlayerSharedApi
import UIKit

final class SearchCoordinator: Coordinator {
    private let hostViewController: MainNavigationUpdatable
    private let mainNavigationHandler: MainNavigationHandler
    private let player: PlayerProtocol
    private let factory: SearchCoordinatorFactoryProtocol
    private let features: Features
    private let navigationController: UINavigationController
    private let playContextFactory: PlayContextFactory
    private let convertLegacyChannelUseCase: any ConvertLegacyChannelUseCase
    private let miniPDPCoordinatorFactory: Factory<MiniPDPCoordinator, MiniPDPCoordinatorInput>
    private let mainScheduler: AnySchedulerOf<DispatchQueue>
    private let persona: Persona
    private let upsellSceneFactory: UpsellSceneFactory

    weak var delegate: CoordinatorDelegate?
    var childCoordinators: [Coordinator] = []
    var childDeeplinkRouters: DeeplinkRoutersList = DeeplinkRoutersList()

    init(
        hostViewController: MainNavigationUpdatable,
        mainNavigationHandler: MainNavigationHandler,
        player: PlayerProtocol = Player.shared,
        factory: SearchCoordinatorFactoryProtocol,
        features: Features,
        navigationController: UINavigationController = GSTMobileBaseNavigationController(),
        playContextFactory: PlayContextFactory,
        convertLegacyChannelUseCase: any ConvertLegacyChannelUseCase,
        miniPDPCoordinatorFactory: Factory<MiniPDPCoordinator, MiniPDPCoordinatorInput>,
        mainScheduler: AnySchedulerOf<DispatchQueue>,
        persona: Persona,
        upsellSceneFactory: UpsellSceneFactory
    ) {
        self.hostViewController = hostViewController
        self.mainNavigationHandler = mainNavigationHandler
        self.player = player
        self.factory = factory
        self.features = features
        self.navigationController = navigationController
        self.playContextFactory = playContextFactory
        self.convertLegacyChannelUseCase = convertLegacyChannelUseCase
        self.miniPDPCoordinatorFactory = miniPDPCoordinatorFactory
        self.mainScheduler = mainScheduler
        self.persona = persona
        self.upsellSceneFactory = upsellSceneFactory
        navigationController.isNavigationBarHidden = true
    }

    func start() {
        internalStart(animated: true)
    }

    func start(with deeplink: Deeplink, animated: Bool) {
        internalStart(animated: animated)
    }

    func handle(deeplink: Deeplink) {
        navigationController.popToRootViewController(animated: false)
    }
}

extension SearchCoordinator: MainNavigationDelegate {
    //swiftlint:disable:next function_body_length
    func navigate(to destination: MainCoordinator.Destination, animated: Bool) {
        switch destination {
        case let .player(asset, _, _, _):
            routeToPlayout(to: asset)
        case let .pdp(asset, _, _):
            routeToPDP(to: asset)
        case let .upsell(asset, contentSegments):
            routeToUpsellJourney(with: asset, contentSegments: contentSegments)
        case let .collectionNavigation(
            template,
            linkId,
            linkIdRank,
            nodeId,
            collectionId,
            title,
            menuTitle,
            curatorAds,
            railIndex,
            fromViewAll,
            _,
            _,
            originTemplate: nil
        ):
            routeToCollectionNavigation(
                with: template,
                linkId: linkId,
                linkIdRank: linkIdRank,
                nodeId: nodeId,
                collectionId: collectionId,
                title: title,
                menuAlias: menuTitle,
                curatorAds: curatorAds,
                animated: true,
                railIndex: railIndex,
                fromViewAll: fromViewAll
            )
        case let .collectionGroup(
            asset,
            _,
            _,
            originTemplate: nil
        ):
            routeToCollectionGroup(with: asset)
        case let .channels(liveProgram, _):
            routeToChannels(with: liveProgram)
        case let .miniPDP(
            railId,
            tileId,
            miniPDPDataSourceType,
            miniPlayersController,
            ctaSetHandler,
            analyticsDataSource
        ):
            routeToMiniPDP(
                railId: railId,
                tileId: tileId,
                dataSourceType: miniPDPDataSourceType,
                miniPlayersController: miniPlayersController,
                ctaSetHandler: ctaSetHandler,
                analyticsDataSource: analyticsDataSource
            )
        default:
            break
        }
    }
}

private extension SearchCoordinator {
    private func internalStart(animated: Bool) {
        let viewController: UIViewController = factory.makeSearchViewController(navigationDelegate: self)
        navigationController.viewControllers = [viewController]
        hostViewController.add(viewController: navigationController, for: .search)
    }

    private func routeToPDP(to asset: Asset) {
        guard let viewController = factory.makePDPViewController(
                with: asset,
                curatorInfo: nil,
                parentRouter: nil,
                navigationController: navigationController) else {
            return
        }
        navigationController.pushViewController(viewController, animated: true)
    }

    private func routeToUpsellJourney(
        with asset: Asset,
        contentSegments: UpsellContentSegments
    ) {
        let upsellCoordinator = UpsellCoordinator(
            hostedBy: navigationController,
            upsellSceneFactory: upsellSceneFactory,
            delegate: self,
            planPickerContext: .pdp(
                assetContentSegments: asset.contentSegments,
                contentSegments: UpsellContentSegments(asset: asset),
                asset: asset
            ),
            asset: asset,
            contentSegments: UpsellContentSegments(asset: asset),
            features: features,
            upsellPresentationType: .present(animated: true)
        )

        addChildCoordinator(upsellCoordinator)
        upsellCoordinator.start()
    }

    private func routeToPlayout(to asset: Asset) {
        guard
            let viewController = navigationController.topViewController,
            let playContext = playContextFactory.makeDefaultContext(
                for: asset,
                videoInitialization: .manual
            )
        else { return }

        player.start(
            context: playContext,
            in: .fullscreen(
                FullscreenPlaybackStyleImpl(
                    options: FullscreenPlayerOptions(
                        hostViewController: viewController,
                        externalPlayerNotificationDelegate: hostViewController as? PlayerNotificationDelegate
                    )
                )
            )
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func routeToCollectionNavigation(
        with template: CollectionGroupRail.RenderHint.Template?,
        linkId: String?,
        linkIdRank: String?,
        nodeId: String?,
        collectionId: String?,
        title: String?,
        menuAlias: String?,
        curatorAds: CollectionGroupRail.Campaign?,
        animated: Bool,
        railIndex: Int?,
        fromViewAll: Bool
    ) {
        let viewController = factory.makeCollectionNavigationViewController(
            template,
            linkId: linkId,
            linkIdRank: linkIdRank,
            nodeId: nodeId,
            collectionId: collectionId,
            title: title,
            menuAlias: menuAlias,
            navigationController: navigationController,
            curatorAds: curatorAds,
            navigationDelegate: self,
            railIndex: railIndex,
            fromViewAll: fromViewAll
        )

        navigationController.pushViewController(viewController, animated: animated)
    }

    private func routeToCollectionGroup(with asset: Asset) {
        let viewController = factory.makeCollectionGroupViewController(
            asset: asset,
            navigationDelegate: self,
            mainNavigationHandler: nil,
            menuAlias: nil,
            catalogueType: nil,
            isMyStuffAvailable: false
        )

        navigationController.pushViewController(viewController, animated: true)
    }

    private func routeToChannels(with liveProgram: WatchLiveProgramModel?) {
        if
            let watchLiveProgramModel = liveProgram,
            let data: (channel: ChannelsApi.Channel, item: ChannelsApi.ScheduleItem?) = convertLegacyChannelUseCase.execute(input: watchLiveProgramModel)
        {
            mainNavigationHandler.updateStore(
                with: data.channel,
                scheduleItem: data.item,
                curatorInfo: nil,
                showInFullScreen: true,
                shouldResetRailPosition: true
            )
        }
        mainNavigationHandler.setSelectedMode(.channels, animated: true, completion: { [weak self] in
            self?.navigationController.popToRootViewController(animated: true)
        })
    }

    // swiftlint:disable:next function_parameter_count
    private func routeToMiniPDP(
        railId: String,
        tileId: String,
        dataSourceType: MiniPDPDataSourceType,
        miniPlayersController: MiniPlayersController?,
        ctaSetHandler: CTASetHandler?,
        analyticsDataSource: MiniPDPAnalyticsDataSource
    ) {
        let coordinator = miniPDPCoordinatorFactory.make(
            MiniPDPCoordinatorInput(
                railId: railId,
                tileId: tileId,
                dataSourceType: dataSourceType,
                isKidsProfile: persona.type == .kid,
                mainScheduler: mainScheduler,
                miniPlayersController: miniPlayersController,
                ctaSetHandler: ctaSetHandler,
                navigationController: navigationController,
                analyticsDataSource: analyticsDataSource
            )
        )

        addChildCoordinator(coordinator)
        coordinator.start()
    }

    private func reportScreenAfterModalDismissIfNeeded(forceReport: Bool = false) {
        guard let topVC = navigationController.topViewController else { return }

        let isNonFullScreenModal = topVC.modalPresentationStyle != .fullScreen
        let isDismissingPresentedVC = topVC.presentedViewController?.isBeingDismissed == true || navigationController.visibleViewController?.isBeingDismissed == true

        if (isNonFullScreenModal && isDismissingPresentedVC) || forceReport {
            (topVC as? ScreenOpeningReporter)?.reportScreenOpenedIfNeeded()
        }
    }
}

extension SearchCoordinator: CoordinatorDelegate {
    func coordinatorDidFinish(_ coordinator: Coordinator, result: Any?) {
        switch coordinator {
        case is MiniPDPCoordinator:
            reportScreenAfterModalDismissIfNeeded(forceReport: true)
        default:
            reportScreenAfterModalDismissIfNeeded()
        }
        removeChildCoordinator(coordinator)
    }
}
