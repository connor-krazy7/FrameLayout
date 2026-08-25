import UIKit

public enum FLVerticalAlignment: Sendable, Hashable {
    case top
    case center
    case bottom

    public func originY(childHeight: CGFloat, containerHeight: CGFloat) -> CGFloat {
        let slack = containerHeight - childHeight

        return switch self {
        case .top: 0
        case .center: slack / 2
        case .bottom: slack
        }
    }
}

