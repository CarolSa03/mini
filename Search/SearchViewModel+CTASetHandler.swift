import ActionsMenuApi
import AppReportingApi
import Browse_Api
import BrowseApi
import Core_Ui_Api
import EventHub
import GSTCoreServicesContinueWatchingApi
import Legacy_Api
import MiniPDPAPI
import PCLSBrowseChannelsCoreApi
import PCLSContinueWatchingApi
import SearchApi
import UIKit

extension SearchViewModel: @preconcurrency CTASetHandler {

    @MainActor func didTapCTA( // swiftlint:disable:this function_parameter_count
        for asset: Legacy_Api.Asset,
        indexPath: IndexPath? = nil,
        tileId: String,
        railId: String? = nil,
        cta: PCLSBrowseChannelsCoreApi.CTASpec,
        railTemplate: Legacy_Api.CollectionGroupRail.RenderHint.Template? = nil,
        actionsMenuCTASets: [PCLSBrowseChannelsCoreApi.CTASpec]?,
        context: Core_Ui_Api.CTAContext,
        buttonText: String?
    ) {
        let resolvedAction = ctaSpecActionResolver.resolveAction(for: cta)
        didTapCTASpec(
            for: asset,
            tileId: tileId,
            cta: cta,
            resolvedAction: resolvedAction,
            actionsMenuCTASets: actionsMenuCTASets,
            context: context,
            buttonText: buttonText
        )
    }

    // swiftlint:disable:next function_parameter_count
    @MainActor func didTapCTASpec(
        for asset: Legacy_Api.Asset,
        tileId: String,
        railId: String? = nil,
        cta: PCLSBrowseChannelsCoreApi.CTASpec,
        indexPath: IndexPath? = nil,
        resolvedAction: Core_Ui_Api.ResolvedAction,
        railTemplate: Legacy_Api.CollectionGroupRail.RenderHint.Template? = nil,
        actionsMenuCTASets: [PCLSBrowseChannelsCoreApi.CTASpec]?,
        context: Core_Ui_Api.CTAContext,
        buttonText: String?
    ) {
        trackAnalytics(
            for: context,
            asset: asset,
            tileId: tileId,
            resolvedAction: resolvedAction,
            cta: cta,
            buttonText: buttonText
        )

        trackPdpMayOpenIfNeeded(for: resolvedAction, in: context)

        switch resolvedAction {
        case .channelGuide(let serviceKey):
            didTapChannelGuide(
                serviceKey,
                asset: asset
            )
        case .watchlist:
            let isInMyStuff = myStuffAssetsHandler.assetExistsInMyStuff(asset)
            didTapWatchlist(
                asset,
                isInMyStuff: isInMyStuff,
                tileId: tileId,
                actionsMenuCTASets: actionsMenuCTASets,
                fromActionsMenu: context == .actionsMenu
            )
        case .upsell:
            routeToUpsell(asset: asset, from: cta)
        case .play(let content):
            didTapPlay(
                asset,
                content: content,
                actionsMenuCTASets: actionsMenuCTASets
            )
        case .open(let destination):
            didTapOpen(asset, destination: destination)
        case .pdp:
            outputEvents.routeToPdp?(asset)
        case .continueWatching, .unresolved:
            // In line with the current app's behaviour if a tap action cannot be resolved, we do nothing
            break
        }
    }

    private func trackPdpMayOpenIfNeeded(for action: ResolvedAction, in context: CTAContext) {
        guard case .pdp = action else { return }

        switch context {
        case .actionsMenu:
            eventHub.emit(SearchCtaClick())
        default:
            eventHub.emit(SearchTileClick())
        }
    }

    @MainActor func didTapCTA(
        cta: PCLSBrowseChannelsCoreApi.CTASpec,
        tileId: String,
        railId: String,
        context: Core_Ui_Api.CTAContext,
        buttonText: String?
    ) {
        let output = resolve(tileId: tileId, contentFormat: .emptySearch)
        let searchTab = searchTabs.getSearchTab(for: .emptySearch)

        self.didTapCTA(
            for: output.asset,
            tileId: output.id,
            cta: cta,
            actionsMenuCTASets: ctaSetHelper.makeCTASets(
                tileId: output.searchTile?.id,
                pageCTASetKey: nil,
                railCTASetKey: searchTab.renderHint?.contextMenuCtaSet,
                tileCTASetKey: nil,
                ctasSets: output.searchTile?.ctaSets,
                context: .search,
                shouldReport: false
            ),
            context: context,
            buttonText: buttonText
        )
    }
}

private extension SearchViewModel {
    func didTapChannelGuide(_ serviceKey: String?, asset: Asset) {
        guard serviceKey != nil else {
            outputEvents.routeToChannel?(nil)
            return
        }

        outputEvents.routeToChannel?(asset as? WatchLiveProgramModel)
    }

    @MainActor func didTapWatchlist(
        _ asset: Legacy_Api.Asset,
        isInMyStuff: Bool,
        tileId: String,
        actionsMenuCTASets: [CTASpec]?,
        fromActionsMenu: Bool
    ) {
        guard
            let uuid = (asset as? MyStuffMember)?.uuid
        else { return }

        if
            let actionMenuIndexPath = findActionMenuIndexPath(
                action: .watchlist,
                actionMenuCtaSets: actionsMenuCTASets
            ),
            fromActionsMenu
        {
            outputEvents.animateMyStuffCTA?(isInMyStuff, actionMenuIndexPath)
        }

        myStuffService.toggleInMyStuff(isInMyStuff: isInMyStuff, uuid: uuid) { [weak self] error in
            guard let self else { return }
            if error != nil {
                if fromActionsMenu {
                    self.outputEvents.dismissActionSheet? {
                        self.mainQueue.async {
                            self.watchlistErrorNotificationFactory.show(dismissAfter: nil, failedToAdd: !isInMyStuff) {
                                self.didTapActionsMenu(
                                    for: asset,
                                    with: tileId,
                                    ctaSets: actionsMenuCTASets
                                )
                            }
                        }
                    }
                } else {
                    watchlistErrorNotificationFactory.show(dismissAfter: nil, failedToAdd: !isInMyStuff, completion: nil)
                }
            } else if fromActionsMenu {
                if uiAccessibilityWrapper.isVoiceOverRunning {
                    let accessibilityLabel = !isInMyStuff
                        ? labels.getLabel(forKey: LocalizationKeys.Accessibility.MyStuff.addToMyStuffAction)
                        : labels.getLabel(forKey: LocalizationKeys.Accessibility.MyStuff.removeFromMyStuffAction)
                    accessibility.addAnnouncementToQueue(accessibilityLabel)
                    notificationCenter.addObserver(
                        self,
                        selector: #selector(dismissActionsMenu),
                        name: UIAccessibility.announcementDidFinishNotification,
                        object: nil
                    )
                } else {
                    self.outputEvents.dismissActionSheet? { }
                }
            }
        }
    }

    func didTapPlay(
        _ asset: Legacy_Api.Asset,
        content: ResolvedAction.Content,
        actionsMenuCTASets: [CTASpec]?
    ) {
        switch content {
        case .programme, .clip, .sle, .fer, .playlist, .epgEvent:
            self.outputEvents.routeToPlayer?(asset)
        case .trailer:
            self.outputEvents.routeToPlayer?(asset.upcomingTrailers ?? asset)
        case .episode:
            self.actionsMenuHelper.getPlaybackAsset(
                for: asset,
                ctaSets: actionsMenuCTASets
            ) { [weak self] episode in
                guard let self else { return }
                self.mainQueue.async { [weak self] in
                    guard let self else { return }
                    self.outputEvents.routeToPlayer?(episode ?? asset)
                }
            }
        }
    }

    func didTapOpen(
        _ asset: Legacy_Api.Asset,
        destination: ResolvedAction.Destination
    ) {
        switch destination {
        case .collection:
            outputEvents.routeToGrid?(asset)
        case .hub, .subGroup:
            outputEvents.routeToCollection?(asset)
        }
    }

    func findActionMenuIndexPath(
        action: PCLSBrowseChannelsCoreApi.CTA.Behaviour.Action,
        actionMenuCtaSets: [CTASpec]?
    ) -> IndexPath? {
        guard let itemIndex = actionMenuCtaSets?.firstIndex(where: { $0.behaviour.action == action }) else { return nil }
        return IndexPath(item: itemIndex, section: 0)
    }

    func trackAnalytics( //swiftlint:disable:this function_parameter_count
        for context: CTAContext,
        asset: Legacy_Api.Asset,
        tileId: String,
        resolvedAction: ResolvedAction,
        cta: CTASpec,
        buttonText: String?
    ) {
        switch context {
        case .actionsMenu:
            trackActionsMenu(
                with: asset,
                tileId: tileId,
                resolvedAction: resolvedAction,
                cta: cta
            )
        case .miniPDP:
            trackMiniPDP(
                with: asset,
                tileId: tileId,
                resolvedAction: resolvedAction,
                cta: cta,
                buttonText: buttonText
            )
        default:
            return
        }
    }
}
