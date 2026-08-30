import UIKit

/// A subtree's overrides. Values, not a closure, so a node carrying them stays `Hashable`.
public struct FLEnvironmentOverrides: Sendable, FLLayoutEquatable {
    public var foregroundColor: UIColor?
    public var font: UIFont?

    public init(foregroundColor: UIColor? = nil, font: UIFont? = nil) {
        self.foregroundColor = foregroundColor
        self.font = font
    }

    public var isEmpty: Bool { foregroundColor == nil && font == nil }

    public func merging(_ other: FLEnvironmentOverrides) -> FLEnvironmentOverrides {
        FLEnvironmentOverrides(
            foregroundColor: foregroundColor.or(other.foregroundColor),
            font: font.or(other.font)
        )
    }
}

// MARK: - FLLayoutEquatable

public extension FLEnvironmentOverrides {
    func isLayoutEquivalent(to other: FLEnvironmentOverrides) -> Bool {
        font == other.font
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(font)
    }
}
