import UIKit

public struct FLAdjustments: Sendable, Hashable, WithCustomisable {
    public var opacity: CGFloat = 1
    public var allowsHitTesting: Bool = true

    public static func clamped(_ opacity: CGFloat) -> CGFloat {
        Swift.min(1, Swift.max(0, opacity))
    }
}
