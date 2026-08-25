import UIKit

public enum FLLayoutDirection: Sendable, Hashable {
    case leftToRight
    case rightToLeft
}

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

/// A subtree's overrides. Values, not a closure, so a node carrying them stays `Hashable`.
public struct FLEnvironmentOverrides: Sendable, Hashable {
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

public extension FLEnvironment {
    func applying(_ overrides: FLEnvironmentOverrides) -> FLEnvironment {
        with {
            $0.foregroundColor = overrides.foregroundColor.or(foregroundColor)
            $0.font = overrides.font.or(font)
        }
    }
}

public struct FLContext: Sendable, Hashable, WithCustomisable {
    public var width: FLProposal
    public var height: FLProposal
    public var environment: FLEnvironment

    public var layoutDirection: FLLayoutDirection { environment.layoutDirection }
    public var contentSizeCategory: String { environment.contentSizeCategory }

    public init(
        width: FLProposal = .unspecified,
        height: FLProposal = .unspecified,
        layoutDirection: FLLayoutDirection = .leftToRight,
        contentSizeCategory: String = UIContentSizeCategory.large.rawValue,
        environment: FLEnvironment? = nil
    ) {
        self.width = width
        self.height = height
        self.environment = environment.or(
            FLEnvironment(layoutDirection: layoutDirection, contentSizeCategory: contentSizeCategory)
        )
    }

    public init(
        width: CGFloat?,
        height: CGFloat? = nil,
        layoutDirection: FLLayoutDirection = .leftToRight,
        contentSizeCategory: String = UIContentSizeCategory.large.rawValue,
        environment: FLEnvironment? = nil
    ) {
        self.init(
            width: width.map(FLProposal.exact).or(.unspecified),
            height: height.map(FLProposal.exact).or(.unspecified),
            layoutDirection: layoutDirection,
            contentSizeCategory: contentSizeCategory,
            environment: environment
        )
    }

    public func applying(_ overrides: FLEnvironmentOverrides) -> FLContext {
        with { $0.environment = $0.environment.applying(overrides) }
    }

    public static var unspecified: FLContext { FLContext() }

    public func proposing(width newWidth: FLProposal, height newHeight: FLProposal) -> FLContext {
        with {
            $0.width = newWidth
            $0.height = newHeight
        }
    }

    public func inset(by insets: FLEdgeInsets) -> FLContext {
        proposing(
            width: width.inset(by: insets.horizontal),
            height: height.inset(by: insets.vertical)
        )
    }

    /// Narrows a computed extent to the proposal, which only bounds it when the proposal is exact.
    public func clampingWidth(_ proposedWidth: CGFloat) -> CGFloat {
        width.exactValue.map { Swift.min($0, proposedWidth) }.or(proposedWidth)
    }

    public func clampingHeight(_ proposedHeight: CGFloat) -> CGFloat {
        height.exactValue.map { Swift.min($0, proposedHeight) }.or(proposedHeight)
    }
}

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

public struct FLEdgeInsets: Sendable, Hashable, WithCustomisable {
    public var top: CGFloat = 0
    public var leading: CGFloat = 0
    public var bottom: CGFloat = 0
    public var trailing: CGFloat = 0

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static var zero: FLEdgeInsets { FLEdgeInsets() }

    public static func all(_ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
    }

    public static func edges(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(
            top: edges.contains(.top) ? inset : 0,
            leading: edges.contains(.leading) ? inset : 0,
            bottom: edges.contains(.bottom) ? inset : 0,
            trailing: edges.contains(.trailing) ? inset : 0
        )
    }

    public var horizontal: CGFloat { leading + trailing }
    public var vertical: CGFloat { top + bottom }

    public func left(in direction: FLLayoutDirection) -> CGFloat {
        direction == .leftToRight ? leading : trailing
    }

    public func adding(_ other: FLEdgeInsets) -> FLEdgeInsets {
        FLEdgeInsets(
            top: top + other.top,
            leading: leading + other.leading,
            bottom: bottom + other.bottom,
            trailing: trailing + other.trailing
        )
    }
}

public enum FLHorizontalAlignment: Sendable, Hashable {
    case leading
    case center
    case trailing

    public func originX(childWidth: CGFloat, containerWidth: CGFloat, direction: FLLayoutDirection) -> CGFloat {
        let slack = containerWidth - childWidth

        return switch self {
        case .center: slack / 2
        case .leading: direction == .leftToRight ? 0 : slack
        case .trailing: direction == .leftToRight ? slack : 0
        }
    }
}

public enum FLVerticalAlignment: Sendable, Hashable {
    case top
    case center
    case bottom

    public func originY(childHeight: CGFloat, containerHeight: CGFloat) -> CGFloat {
        let slack = containerHeight - childHeight

        return switch self {
        case .top: 0
        case .center: slack / 2
        case .bottom: slack
        }
    }
}

public struct FLAlignment: Sendable, Hashable {
    public var horizontal: FLHorizontalAlignment
    public var vertical: FLVerticalAlignment

    public init(horizontal: FLHorizontalAlignment, vertical: FLVerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static var topLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .top) }
    public static var top: FLAlignment { FLAlignment(horizontal: .center, vertical: .top) }
    public static var topTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .top) }
    public static var leading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .center) }
    public static var center: FLAlignment { FLAlignment(horizontal: .center, vertical: .center) }
    public static var trailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .center) }
    public static var bottomLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .bottom) }
    public static var bottom: FLAlignment { FLAlignment(horizontal: .center, vertical: .bottom) }
    public static var bottomTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .bottom) }

    public func origin(
        childSize: CGSize,
        containerSize: CGSize,
        direction: FLLayoutDirection
    ) -> CGPoint {
        CGPoint(
            x: horizontal.originX(
                childWidth: childSize.width,
                containerWidth: containerSize.width,
                direction: direction
            ),
            y: vertical.originY(
                childHeight: childSize.height,
                containerHeight: containerSize.height
            )
        )
    }
}

public protocol FLLayout: Sendable, Equatable {
    var size: CGSize { get }
}

public protocol FLNodeProviding {
    associatedtype ProvidedNode: FLNode

    var flNode: ProvidedNode { get }
}

public protocol FLNode: FLNodeProviding, Sendable, Hashable {
    associatedtype Layout: FLLayout
    associatedtype View: FLNodeView where View.Node == Self

    static var typeIdentifier: String { get }

    var isSpacer: Bool { get }

    func layout(in context: FLContext) -> Layout
}

public extension FLNode {
    var isSpacer: Bool { false }

    var flNode: Self { self }
}

@MainActor
public protocol FLNodeView: UIView {
    associatedtype Node: FLNode

    init()

    func update(node: Node, layout: Node.Layout, context: FLRenderContext)
}
