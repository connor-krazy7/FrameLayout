import UIKit

/// Values that flow down the tree rather than being proposed. Present in `FLContext` because some of
/// them (font, content size category) affect measurement, and passed to `update` because others
/// (colours) only affect drawing.
public struct FLEnvironment: Sendable, Hashable, WithCustomisable {
    public var layoutDirection: FLLayoutDirection
    public var contentSizeCategory: String
    public var foregroundColor: UIColor?
    public var font: UIFont?

    public init(
        layoutDirection: FLLayoutDirection = .leftToRight,
        contentSizeCategory: String = UIContentSizeCategory.large.rawValue,
        foregroundColor: UIColor? = nil,
        font: UIFont? = nil
    ) {
        self.layoutDirection = layoutDirection
        self.contentSizeCategory = contentSizeCategory
        self.foregroundColor = foregroundColor
        self.font = font
    }

    public static var `default`: FLEnvironment { FLEnvironment() }
}

public extension FLEnvironment {
    func applying(_ overrides: FLEnvironmentOverrides) -> FLEnvironment {
        with {
            $0.foregroundColor = overrides.foregroundColor.or(foregroundColor)
            $0.font = overrides.font.or(font)
        }
    }
}
