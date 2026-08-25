import UIKit

public struct FLGridItem: Sendable, Hashable {
    public enum Size: Sendable, Hashable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat, maximum: CGFloat)
        case adaptive(minimum: CGFloat, maximum: CGFloat)
    }

    public var size: Size
    public var spacing: CGFloat?
    public var alignment: FLAlignment?

    public init(_ size: Size, spacing: CGFloat? = nil, alignment: FLAlignment? = nil) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }

    public static func fixed(
        _ extent: CGFloat,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.fixed(extent), spacing: spacing, alignment: alignment)
    }

    public static func flexible(
        minimum: CGFloat = 0,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.flexible(minimum: minimum, maximum: maximum), spacing: spacing, alignment: alignment)
    }

    public static func adaptive(
        minimum: CGFloat,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing, alignment: alignment)
    }
}
