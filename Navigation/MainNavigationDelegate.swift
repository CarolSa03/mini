import Analytics
import BrowseApi
import ChannelsApi
import Collections_Api
import Core_Ui_Api
import GamesApi
import Legacy_Api
import MiniPDPAPI
import PersonasApi
import PlayerContextApi

protocol MainNavigationDelegate: AnyObject {
    func navigate(to destination: MainCoordinator.Destination, animated: Bool)
}

extension MainNavigationDelegate {
    func navigate(to destination: MainCoordinator.Destination) {
        navigate(to: destination, animated: true)
    }
}

extension MainCoordinator {
    enum Destination {
        case player(Legacy_Api.Asset, String?, CuratorInfo?, PlayContext?)
        case pdp(Legacy_Api.Asset, CuratorInfo?, ((Bool) -> Void)?)
        case collectionGroup(
            Legacy_Api.Asset,
            String?,
            String?,
            originTemplate: CollectionGroupRail.RenderHint.Template?
        )
        case collectionNavigation(
            CollectionGroupRail.RenderHint.Template?,
            String?,
            String?,
            String?,
            String?,
            String?,
            String?,
            CollectionGroupRail.Campaign?,
            Int? = nil,
            Bool = false,
            String?,
            String? = nil,
            originTemplate: CollectionGroupRail.RenderHint.Template?
        )
        case planPicker(String?)
        case upsell(Legacy_Api.Asset, UpsellContentSegments)
        case roadblock(Persona)
        case channels(WatchLiveProgramModel?, CuratorInfo?)
        case jumbotron(Jumbotron)
        case game(
            tileId: String,
            config: GameWebViewConfig,
            asset: Asset,
            section: String,
            contentExperiencesFeatures: [String]?
        )
        case editProfile(Persona)
        case onBoarding(Persona)
        case interactiveSchedule(Legacy_Api.ScheduleInfo?, InteractiveScheduleData)
        case lazyLoadingCollectionGridV2(
            linkId: String?,
            collectionId: String?,
            nodeId: String?,
            title: String?,
            sponsor: BrowseApi.Sponsor?,
            fromViewAll: Bool,
            alias: String?
        )
        case lazyLoadingCollectionGroupV2(
            nodeId: String,
            title: String?,
            alias: String?
        )
        case voiceAIExperience
        case miniPDP(
            railId: String,
            tileId: String,
            miniPDPDataSourceType: MiniPDPDataSourceType,
            miniPlayersController: MiniPlayersController?,
            ctaSetHandler: CTASetHandler?,
            analyticsDataSource: MiniPDPAnalyticsDataSource
        )
        case subscriptionOnHold

        #if ALLOW_DEV_TOOLS
        case tileDebug(property: Any)
        #endif
    }
}

extension MainCoordinator.Destination {
    struct InteractiveScheduleData {
        let scheduleId: String?
        let title: String?
        let sponsorImageURL: String?
        let sponsor: String?
    }
}
