import UIKit

public struct FLEdgeSet: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let top = FLEdgeSet(rawValue: 1 << 0)
    public static let leading = FLEdgeSet(rawValue: 1 << 1)
    public static let bottom = FLEdgeSet(rawValue: 1 << 2)
    public static let trailing = FLEdgeSet(rawValue: 1 << 3)

    public static let horizontal: FLEdgeSet = [.leading, .trailing]
    public static let vertical: FLEdgeSet = [.top, .bottom]
    public static let all: FLEdgeSet = [.top, .leading, .bottom, .trailing]
}
