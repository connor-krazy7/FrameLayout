import UIKit

/// A `CGPoint` a node can store: `CGPoint: Hashable` is iOS 18 and this package targets iOS 17, so a
/// stored one traps — see `node-equality.md`. Delete when the minimum reaches iOS 18.
public struct FLPoint: Sendable, Hashable, FLLayoutEquatable {
    public var x: CGFloat = 0
    public var y: CGFloat = 0

    public init(x: CGFloat = 0, y: CGFloat = 0) {
        self.x = x
        self.y = y
    }

    public init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    public static var zero: FLPoint { FLPoint() }
}
