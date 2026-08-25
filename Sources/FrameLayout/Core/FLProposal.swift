import UIKit

/// What a parent offers a child along one axis.
///
/// `minimum` / `maximum` are cases rather than sentinel values (`0` / `.infinity`) so that
/// propagation through modifiers is explicit instead of relying on arithmetic identities, and so
/// that adding a case is a compile error in every node that has to answer it.
public enum FLProposal: Sendable, Hashable {
    /// Report your ideal size.
    case unspecified
    /// Report the smallest you can be.
    case minimum
    /// Report the largest you can be.
    case maximum
    /// Size yourself for exactly this extent.
    case exact(CGFloat)

    public var exactValue: CGFloat? {
        guard case let .exact(value) = self else { return nil }
        return value
    }

    public func inset(by amount: CGFloat) -> FLProposal {
        guard case let .exact(value) = self else { return self }
        return .exact(Swift.max(0, value - amount))
    }

    public func resolved(ideal: CGFloat) -> CGFloat {
        switch self {
        case .unspecified: ideal
        case .minimum: 0
        case .maximum: .infinity
        case let .exact(value): value
        }
    }
}

