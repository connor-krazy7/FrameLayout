import UIKit

/// A `CGSize` a node can store. See `FLPoint` for why, and delete both when the minimum reaches iOS 18.
public struct FLSize: Sendable, Hashable, FLLayoutEquatable {
    public var width: CGFloat = 0
    public var height: CGFloat = 0

    public init(width: CGFloat = 0, height: CGFloat = 0) {
        self.width = width
        self.height = height
    }

    public init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }

    public var cgSize: CGSize { CGSize(width: width, height: height) }

    public static var zero: FLSize { FLSize() }
}
