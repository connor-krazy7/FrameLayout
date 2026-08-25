import UIKit

public enum FLScrollAxis: Sendable, Hashable {
    case vertical
    case horizontal
    case both

    var scrollsVertically: Bool { self != .horizontal }
    var scrollsHorizontally: Bool { self != .vertical }
}
