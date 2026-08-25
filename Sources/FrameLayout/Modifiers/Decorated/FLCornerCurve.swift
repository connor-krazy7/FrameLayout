import UIKit

public enum FLCornerCurve: Sendable, Hashable {
    case circular
    case continuous

    public var layerCornerCurve: CALayerCornerCurve {
        switch self {
        case .circular: .circular
        case .continuous: .continuous
        }
    }
}
