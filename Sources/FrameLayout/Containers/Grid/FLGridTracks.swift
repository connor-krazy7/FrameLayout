import UIKit

public struct FLGridTracks: Sendable, Hashable, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
    public let items: [FLGridItem]

    public init(_ items: [FLGridItem]) {
        self.items = items
    }

    public init(integerLiteral count: Int) {
        items = Array(repeating: FLGridItem.flexible(), count: Swift.max(1, count))
    }

    public init(arrayLiteral elements: FLGridItem...) {
        items = elements
    }

    public static func fixed(_ extent: CGFloat, spacing: CGFloat? = nil) -> FLGridTracks {
        FLGridTracks([.fixed(extent, spacing: spacing)])
    }

    public static func flexible(
        minimum: CGFloat = 0,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil
    ) -> FLGridTracks {
        FLGridTracks([.flexible(minimum: minimum, maximum: maximum, spacing: spacing)])
    }

    public static func adaptive(
        minimum: CGFloat,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil
    ) -> FLGridTracks {
        FLGridTracks([.adaptive(minimum: minimum, maximum: maximum, spacing: spacing)])
    }
}
