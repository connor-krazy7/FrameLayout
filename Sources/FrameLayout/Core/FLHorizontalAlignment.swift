import UIKit

public enum FLHorizontalAlignment: Sendable, Hashable {
    case leading
    case center
    case trailing

    public func originX(childWidth: CGFloat, containerWidth: CGFloat, direction: FLLayoutDirection) -> CGFloat {
        let slack = containerWidth - childWidth

        return switch self {
        case .center: slack / 2
        case .leading: direction == .leftToRight ? 0 : slack
        case .trailing: direction == .leftToRight ? slack : 0
        }
    }
}

