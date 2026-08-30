import UIKit

/// A `CGRect` a node can store. See `FLPoint` for why, and delete all three when the minimum reaches
/// iOS 18.
public struct FLRect: Sendable, Hashable, FLLayoutEquatable {
    public var origin: FLPoint = .zero
    public var size: FLSize = .zero

    public init(origin: FLPoint = .zero, size: FLSize = .zero) {
        self.origin = origin
        self.size = size
    }

    public init(_ rect: CGRect) {
        self.init(origin: FLPoint(rect.origin), size: FLSize(rect.size))
    }

    public var cgRect: CGRect { CGRect(origin: origin.cgPoint, size: size.cgSize) }

    public static var zero: FLRect { FLRect() }
}
