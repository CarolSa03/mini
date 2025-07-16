import UIKit

enum OrientationMode {
    case normal
    case kids
}

protocol DeviceOrientationManaging: OrientationRetrievable, ValueSettable {}

protocol OrientationRetrievable {
    var orientation: UIDeviceOrientation { get }
}

protocol ValueSettable {
    func setValue(_ value: Any?, forKey key: String)
}

extension UIDevice: DeviceOrientationManaging {}

final class OrientationController {

    private let device: DeviceOrientationManaging
    var current = OrientationMode.normal {
        didSet {
            guard current == .kids else { return }
            let desiredOrientation: UIDeviceOrientation = device.orientation == .landscapeRight ? .landscapeRight : .landscapeLeft
            device.setValue(desiredOrientation.rawValue, forKey: "orientation")
        }
    }

    init(current: OrientationMode = .normal, device: DeviceOrientationManaging = UIDevice.current) {
        self.current = current
        self.device = device
    }

    func supported(for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> UIInterfaceOrientationMask {
        switch current {
        case .normal:
            return idiom.isPad ? .all : .portrait
        case .kids:
            return .landscape
        }
    }
}
