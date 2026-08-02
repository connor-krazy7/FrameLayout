import UIKit

enum FLLayoutDirection: Sendable, Hashable {
    case leftToRight
    case rightToLeft
}

/// What a parent offers a child along one axis.
///
/// `minimum` / `maximum` are cases rather than sentinel values (`0` / `.infinity`) so that
/// propagation through modifiers is explicit instead of relying on arithmetic identities, and so
/// that adding a case is a compile error in every node that has to answer it.
enum FLProposal: Sendable, Hashable {
    /// Report your ideal size.
    case unspecified
    /// Report the smallest you can be.
    case minimum
    /// Report the largest you can be.
    case maximum
    /// Size yourself for exactly this extent.
    case exact(CGFloat)

    var exactValue: CGFloat? {
        guard case let .exact(value) = self else { return nil }
        return value
    }

    func inset(by amount: CGFloat) -> FLProposal {
        guard case let .exact(value) = self else { return self }
        return .exact(Swift.max(0, value - amount))
    }
}

/// Values that flow down the tree rather than being proposed. Present in `FLContext` because some of
/// them (font, content size category) affect measurement, and passed to `update` because others
/// (colours) only affect drawing.
struct FLEnvironment: Sendable, Hashable, WithCustomisable {
    var layoutDirection: FLLayoutDirection
    var contentSizeCategory: String
    var foregroundColor: UIColor?
    var font: UIFont?

    init(
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

    static var `default`: FLEnvironment { FLEnvironment() }
}

/// A subtree's overrides. Values, not a closure, so a node carrying them stays `Hashable`.
struct FLEnvironmentOverrides: Sendable, Hashable {
    var foregroundColor: UIColor?
    var font: UIFont?

    var isEmpty: Bool { foregroundColor == nil && font == nil }

    func merging(_ other: FLEnvironmentOverrides) -> FLEnvironmentOverrides {
        FLEnvironmentOverrides(
            foregroundColor: foregroundColor.or(other.foregroundColor),
            font: font.or(other.font)
        )
    }
}

extension FLEnvironment {
    func applying(_ overrides: FLEnvironmentOverrides) -> FLEnvironment {
        with {
            $0.foregroundColor = overrides.foregroundColor.or(foregroundColor)
            $0.font = overrides.font.or(font)
        }
    }
}

struct FLContext: Sendable, Hashable, WithCustomisable {
    var width: FLProposal
    var height: FLProposal
    var environment: FLEnvironment

    var layoutDirection: FLLayoutDirection { environment.layoutDirection }
    var contentSizeCategory: String { environment.contentSizeCategory }

    init(
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

    init(
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

    func applying(_ overrides: FLEnvironmentOverrides) -> FLContext {
        with { $0.environment = $0.environment.applying(overrides) }
    }

    static var unspecified: FLContext { FLContext() }

    func proposing(width newWidth: FLProposal, height newHeight: FLProposal) -> FLContext {
        with {
            $0.width = newWidth
            $0.height = newHeight
        }
    }

    func inset(by insets: FLEdgeInsets) -> FLContext {
        proposing(
            width: width.inset(by: insets.horizontal),
            height: height.inset(by: insets.vertical)
        )
    }

    /// Narrows a computed extent to the proposal, which only bounds it when the proposal is exact.
    func clampingWidth(_ proposedWidth: CGFloat) -> CGFloat {
        width.exactValue.map { Swift.min($0, proposedWidth) }.or(proposedWidth)
    }

    func clampingHeight(_ proposedHeight: CGFloat) -> CGFloat {
        height.exactValue.map { Swift.min($0, proposedHeight) }.or(proposedHeight)
    }
}

struct FLEdgeSet: OptionSet, Sendable, Hashable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let top = FLEdgeSet(rawValue: 1 << 0)
    static let leading = FLEdgeSet(rawValue: 1 << 1)
    static let bottom = FLEdgeSet(rawValue: 1 << 2)
    static let trailing = FLEdgeSet(rawValue: 1 << 3)

    static let horizontal: FLEdgeSet = [.leading, .trailing]
    static let vertical: FLEdgeSet = [.top, .bottom]
    static let all: FLEdgeSet = [.top, .leading, .bottom, .trailing]
}

struct FLCorners: OptionSet, Sendable, Hashable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let topLeading = FLCorners(rawValue: 1 << 0)
    static let topTrailing = FLCorners(rawValue: 1 << 1)
    static let bottomLeading = FLCorners(rawValue: 1 << 2)
    static let bottomTrailing = FLCorners(rawValue: 1 << 3)

    static let top: FLCorners = [.topLeading, .topTrailing]
    static let bottom: FLCorners = [.bottomLeading, .bottomTrailing]
    static let leading: FLCorners = [.topLeading, .bottomLeading]
    static let trailing: FLCorners = [.topTrailing, .bottomTrailing]
    static let all: FLCorners = [.top, .bottom]

    func cornerMask(in direction: FLLayoutDirection) -> CACornerMask {
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

struct FLEdgeInsets: Sendable, Hashable, WithCustomisable {
    var top: CGFloat = 0
    var leading: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0

    static var zero: FLEdgeInsets { FLEdgeInsets() }

    static func all(_ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
    }

    static func edges(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(
            top: edges.contains(.top) ? inset : 0,
            leading: edges.contains(.leading) ? inset : 0,
            bottom: edges.contains(.bottom) ? inset : 0,
            trailing: edges.contains(.trailing) ? inset : 0
        )
    }

    var horizontal: CGFloat { leading + trailing }
    var vertical: CGFloat { top + bottom }

    func left(in direction: FLLayoutDirection) -> CGFloat {
        direction == .leftToRight ? leading : trailing
    }

    func adding(_ other: FLEdgeInsets) -> FLEdgeInsets {
        FLEdgeInsets(
            top: top + other.top,
            leading: leading + other.leading,
            bottom: bottom + other.bottom,
            trailing: trailing + other.trailing
        )
    }
}

enum FLHorizontalAlignment: Sendable, Hashable {
    case leading
    case center
    case trailing

    func originX(childWidth: CGFloat, containerWidth: CGFloat, direction: FLLayoutDirection) -> CGFloat {
        let slack = containerWidth - childWidth

        return switch self {
        case .center: slack / 2
        case .leading: direction == .leftToRight ? 0 : slack
        case .trailing: direction == .leftToRight ? slack : 0
        }
    }
}

enum FLVerticalAlignment: Sendable, Hashable {
    case top
    case center
    case bottom

    func originY(childHeight: CGFloat, containerHeight: CGFloat) -> CGFloat {
        let slack = containerHeight - childHeight

        return switch self {
        case .top: 0
        case .center: slack / 2
        case .bottom: slack
        }
    }
}

struct FLAlignment: Sendable, Hashable {
    var horizontal: FLHorizontalAlignment
    var vertical: FLVerticalAlignment

    init(horizontal: FLHorizontalAlignment, vertical: FLVerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    static var topLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .top) }
    static var top: FLAlignment { FLAlignment(horizontal: .center, vertical: .top) }
    static var topTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .top) }
    static var leading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .center) }
    static var center: FLAlignment { FLAlignment(horizontal: .center, vertical: .center) }
    static var trailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .center) }
    static var bottomLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .bottom) }
    static var bottom: FLAlignment { FLAlignment(horizontal: .center, vertical: .bottom) }
    static var bottomTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .bottom) }

    func origin(
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

protocol FLLayout: Sendable, Equatable {
    var size: CGSize { get }
}

protocol FLNodeProviding {
    associatedtype ProvidedNode: FLNode

    var flNode: ProvidedNode { get }
}

protocol FLNode: FLNodeProviding, Sendable, Hashable {
    associatedtype Layout: FLLayout
    associatedtype View: FLNodeView where View.Node == Self

    static var typeIdentifier: String { get }

    var isSpacer: Bool { get }

    func layout(in context: FLContext) -> Layout
}

extension FLNode {
    var isSpacer: Bool { false }

    var flNode: Self { self }
}

@MainActor
protocol FLNodeView: UIView {
    associatedtype Node: FLNode

    init()

    func update(node: Node, layout: Node.Layout, context: FLRenderContext)
}
