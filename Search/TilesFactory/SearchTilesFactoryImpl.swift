import AppSettings_Api
import Browse_Api
import Core_Ui_Api
import Legacy_Api
import PCLSLabelsApi
import Tiles_Api
import UIKit

protocol SearchTilesFactory: LazyTileFactory { }
final class SearchTilesFactoryImpl: TilesFactoryImpl, SearchTilesFactory {
    private var features: Features
    private var labels: Labels

    private init(
        factories: [TilesType: LazyTileFactory],
        labels: Labels,
        features: Features
    ) {
        self.labels = labels
        self.features = features
        super.init(factories: factories)
    }

    convenience init(
        features: Features,
        util: TileViewModelMapperUtil,
        labels: Labels,
        metadataFactory: TileMetadataFactory
    ) {
        if features.isEnabled(.searchPortraitTileRatio) {
            self.init(
                factories: [
                    .clip: TileFactoryImpl<ClipTile34ViewFactory>(mapper: ClipTile34ViewModelMapper(util: util)),
                    .collectionTile: TileFactoryImpl<CollectionHubTile34ViewFactory>(mapper: CollectionHubTile34ViewModelMapper(labels: labels, util: util)),
                    .episode: TileFactoryImpl<EpisodeTile34ViewFactory>(mapper: EpisodeTile34ViewModelMapper(util: util)),
                    .linear: TileFactoryImpl<LinearChannelTile34ViewFactory>(mapper: LinearChannelTile34ViewModelMapper(util: util)),
                    .movies: TileFactoryImpl<VodTile34ViewFactory>(mapper: VodTile34ViewModelMapper(util: util)),
                    .playlist: TileFactoryImpl<PlaylistTile34ViewFactory>(mapper: PlaylistTile34ViewModelMapper(labels: labels, util: util)),
                    .sle: TileFactoryImpl<SLETile34ViewFactory>(mapper: SLETile34ViewModelMapper(util: util)),
                    .trailer: TileFactoryImpl<TrailerTile34ViewFactory>(mapper: TrailerTile34ViewModelMapper(labels: labels, util: util)),
                    .vodChannel: TileFactoryImpl<VodChannelTile34ViewFactory>(mapper: VodChannelTile34ViewModelMapper(labels: labels, util: util)),
                    .linearEPG: TileFactoryImpl<LinearEPGTile34ViewFactory>(mapper: LinearEPGTile34ViewModelMapper(util: util)),
                    .vodPlaylistEPG: TileFactoryImpl<VODPlaylistEPGTile34ViewFactory>(mapper: VODPlaylistEPGTile34ViewModelMapper(labels: labels, util: util)),
                    .placeholder: TileFactoryImpl<PlaceholderTile34ViewFactory>(mapper: PlaceholderTileViewModelMapper())
                ],
                labels: labels,
                features: features
            )
        } else {
            self.init(
                factories: [
                    .clip: TileFactoryImpl<ClipSearchTile169ViewFactory>(mapper: ClipSearchTile169ViewModelMapper()),
                    .collectionTile: TileFactoryImpl<CollectionHubTile169ViewFactory>(mapper: CollectionHubTile169ViewModelMapper()),
                    .episode: TileFactoryImpl<EpisodeTile169ViewFactory>(mapper: EpisodeTile169ViewModelMapper(util: util)),
                    .linear: TileFactoryImpl<LinearChannelLargeTile169ViewFactory>(mapper: LinearChannelTile169ViewModelMapper(util: util)),
                    .movies: TileFactoryImpl<VodTileLarge169ViewFactory>(mapper: VodTile169ViewModelMapper(util: util, metadataFactory: metadataFactory)),
                    .playlist: TileFactoryImpl<PlaylistTile169ViewFactory>(mapper: PlaylistTile169ViewModelMapper(labels: labels)),
                    .sle: TileFactoryImpl<SLELargeTile169ViewFactory>(mapper: SLETile169ViewModelMapper(util: util)),
                    .trailer: TileFactoryImpl<TrailerTile169ViewFactory>(mapper: TrailerTile169ViewModelMapper()),
                    .vodChannel: TileFactoryImpl<VodChannelLargeTile169ViewFactory>(mapper: VodChannelTile169ViewModelMapper(labels: labels, util: util)),
                    .linearEPG: TileFactoryImpl<LinearEPGTile169ViewFactory>(mapper: LinearEPGTile169ViewModelMapper(util: util)),
                    .vodPlaylistEPG: TileFactoryImpl<VODPlaylistEPGTile169ViewFactory>(mapper: VODPlaylistEPGTile169ViewModelMapper(labels: labels, util: util)),
                    .placeholder: TileFactoryImpl<PlaceholderTile169ViewFactory>(mapper: PlaceholderTileViewModelMapper())
                ],
                labels: labels,
                features: features
            )
        }
    }

    // swiftlint:disable:next function_body_length
    override func cell(
        for tile: TileViewModelMapperFeeder,
        at indexPath: IndexPath,
        collectionView: UICollectionView
    ) -> UICollectionViewCell {
        switch tile.type {
        case
            .clip,
            .collectionTile,
            .episode,
            .linear,
            .movies,
            .playlist,
            .sle,
            .trailer,
            .vodChannel,
            .linearEPG,
            .vodPlaylistEPG,
            .placeholder:
            return super.cell(
                for: tile,
                at: indexPath,
                collectionView: collectionView
            )
        case
            .game,
            .episodeCW,
            .moviesCW,
            .sleCW,
            .gridGroupCollection,
            .placeholderGenreTile,
            .clipHighlight,
            .episodeHighlight,
            .highlight,
            .linearHighlight,
            .playlistHighlight,
            .sleHighlight,
            .trailerHighlight,
            .vodChannelHighlight,
            .clipLarge,
            .collectionTileLarge,
            .groupHighlight,
            .episodeLarge,
            .linearLarge,
            .moviesLarge,
            .playlistLarge,
            .sleLarge,
            .trailerLarge,
            .vodChannelLarge,
            .vodChannelFeatured,
            .linearFeatured,
            .kidsHighlight,
            .kids,
            .jumbotron,
            .liveSchedule,
            .placeholderConnectedNavTile:
            assertionFailure("Failed to match tile of type \(tile.type) to any supported cell type")
            return fallbackCell(
                at: indexPath,
                collectionView: collectionView
            )
        }
    }
}
