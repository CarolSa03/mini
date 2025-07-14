import UIKit

final class RecentSearchesCollectionViewFlowLayout: UICollectionViewFlowLayout {
    private let style = SearchStyle.RecentSearchesStyle.defaultStyle()

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else { return }

        let insets = style.sectionInset(collectionView.traitCollection)
        let itemWidth = collectionView.frame.size.width - insets.left - insets.right
        itemSize = CGSize(width: itemWidth, height: style.rowHeight)
        headerReferenceSize = CGSize(width: itemWidth, height: style.rowHeight)
        sectionInset = style.sectionInset(collectionView.traitCollection)
    }
}
