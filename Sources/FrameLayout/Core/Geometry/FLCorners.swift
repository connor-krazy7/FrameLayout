import UIKit

public struct FLCorners: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let topLeading = FLCorners(rawValue: 1 << 0)
    public static let topTrailing = FLCorners(rawValue: 1 << 1)
    public static let bottomLeading = FLCorners(rawValue: 1 << 2)
    public static let bottomTrailing = FLCorners(rawValue: 1 << 3)

    public static let top: FLCorners = [.topLeading, .topTrailing]
    public static let bottom: FLCorners = [.bottomLeading, .bottomTrailing]
    public static let leading: FLCorners = [.topLeading, .bottomLeading]
    public static let trailing: FLCorners = [.topTrailing, .bottomTrailing]
    public static let all: FLCorners = [.top, .bottom]

    public func cornerMask(in direction: FLLayoutDirection) -> CACornerMask {
        let isLeftToRight = direction == .leftToRight

        var mask: CACornerMask = []
        if contains(.topLeading) {
            mask.insert(isLeftToRight ? .layerMinXMinYCorner : .layerMaxXMinYCorner)
        }
        if contains(.topTrailing) {
            mask.insert(isLeftToRight ? .layerMaxXMinYCorner : .layerMinXMinYCorner)
        }
        if contains(.bottomLeading) {
            mask.insert(isLeftToRight ? .layerMinXMaxYCorner : .layerMaxXMaxYCorner)
        }
        if contains(.bottomTrailing) {
            mask.insert(isLeftToRight ? .layerMaxXMaxYCorner : .layerMinXMaxYCorner)
        }
        return mask
    }
}
