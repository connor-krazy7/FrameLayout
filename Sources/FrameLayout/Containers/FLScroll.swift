import UIKit

public enum FLScrollAxis: Sendable, Hashable {
    case vertical
    case horizontal
    case both

    var scrollsVertically: Bool { self != .horizontal }
    var scrollsHorizontally: Bool { self != .vertical }
}

public enum FLScrollIndicatorVisibility: Sendable, Hashable {
    case automatic
    case hidden
}

/// A type-erased, `Sendable` box for the reset token: `AnyHashable` is not `Sendable`, and a node must be.
public struct FLScrollIdentity: Sendable, Hashable {
    private let token: any Hashable & Sendable

    init(_ token: some Hashable & Sendable) {
        self.token = token
    }

    public static func == (lhs: FLScrollIdentity, rhs: FLScrollIdentity) -> Bool {
        AnyHashable(lhs.token) == AnyHashable(rhs.token)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(token))
    }
}

public struct FLScrollConfiguration: Sendable, Hashable, WithCustomisable {
    public var resetToken: FLScrollIdentity?
    public var indicators: FLScrollIndicatorVisibility = .automatic
    public var contentInsets: FLEdgeInsets = .zero
    public var isScrollDisabled = false
    public var bounces = true
    public var isPagingEnabled = false
    public var keyboardDismissMode: UIScrollView.KeyboardDismissMode = .none
    public var contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior = .never
}

public struct FLScrollLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout
    public let contentSize: CGSize
    public let size: CGSize
}

/// A scrolling region inside a tree. The content is always measured unbounded along the scroll axis, so it
/// reports its natural extent as the content size, while the region takes the extent it was offered — or
/// collapses to its content when nothing was offered, which is how a scroll view behaves in a self-sizing
/// cell. Bounding it with `frame(maxHeight:)` is what turns it into a viewport. Across the axis it hugs the
/// content rather than filling what it was offered — measured against SwiftUI, which does the same.
///
/// Eager: applying the tree builds every child view. Suited to a chip row or a sheet body, not to a feed,
/// where a `UICollectionView` with an `FLHostView` per cell remains the answer.
public struct FLScroll<Content: FLNode>: FLNode {
    public typealias View = FLScrollView<Content>

    public static var typeIdentifier: String { "scroll(\(Content.typeIdentifier))" }

    public let axis: FLScrollAxis
    public let configuration: FLScrollConfiguration
    public let content: Content

    public init(_ axis: FLScrollAxis = .vertical, @FLNodeBuilder content: () -> Content) {
        self.init(axis: axis, configuration: FLScrollConfiguration(), content: content())
    }

    init(axis: FLScrollAxis, configuration: FLScrollConfiguration, content: Content) {
        self.axis = axis
        self.configuration = configuration
        self.content = content
    }

    public func layout(in context: FLContext) -> FLScrollLayout<Content.Layout> {
        let contentLayout = content.layout(
            in: context.proposing(
                width: axis.scrollsHorizontally ? .unspecified : context.width,
                height: axis.scrollsVertically ? .unspecified : context.height
            )
        )
        let size = CGSize(
            width: axis.scrollsHorizontally
                ? context.width.resolved(ideal: contentLayout.size.width)
                : contentLayout.size.width,
            height: axis.scrollsVertically
                ? context.height.resolved(ideal: contentLayout.size.height)
                : contentLayout.size.height
        )

        return FLScrollLayout(wrapped: contentLayout, contentSize: contentLayout.size, size: size)
    }
}

public extension FLScroll {
    /// Resets the offset when the token changes, which keeps a reused view from inheriting the previous
    /// item's position. Nodes hold no state, so the identity has to arrive as a value.
    func resetting(_ token: some Hashable & Sendable) -> FLScroll {
        configured { $0.resetToken = FLScrollIdentity(token) }
    }

    func scrollIndicators(_ visibility: FLScrollIndicatorVisibility) -> FLScroll {
        configured { $0.indicators = visibility }
    }

    func contentInsets(_ insets: FLEdgeInsets) -> FLScroll {
        configured { $0.contentInsets = insets }
    }

    func scrollDisabled(_ isDisabled: Bool = true) -> FLScroll {
        configured { $0.isScrollDisabled = isDisabled }
    }

    func bounces(_ bounces: Bool) -> FLScroll {
        configured { $0.bounces = bounces }
    }

    func paging(_ isEnabled: Bool = true) -> FLScroll {
        configured { $0.isPagingEnabled = isEnabled }
    }

    func keyboardDismissMode(_ mode: UIScrollView.KeyboardDismissMode) -> FLScroll {
        configured { $0.keyboardDismissMode = mode }
    }

    func contentInsetAdjustmentBehavior(
        _ behavior: UIScrollView.ContentInsetAdjustmentBehavior
    ) -> FLScroll {
        configured { $0.contentInsetAdjustmentBehavior = behavior }
    }

    private func configured(_ transform: (inout FLScrollConfiguration) -> Void) -> FLScroll {
        FLScroll(axis: axis, configuration: configuration.with(transform), content: content)
    }
}

public final class FLScrollView<Content: FLNode>: UIScrollView, FLNodeView {
    public typealias Node = FLScroll<Content>

    private let contentView = Content.View()
    private var appliedToken: FLScrollIdentity?
    private var hasApplied = false

    public override init(frame: CGRect) {
        super.init(frame: frame)

        delaysContentTouches = false
        canCancelContentTouches = true
        addSubview(contentView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `UIScrollView` refuses to cancel touches inside a `UIControl`, which would leave a drag that starts on
    /// an `FLButton` unable to scroll.
    public override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }

    public func update(node: Node, layout: FLScrollLayout<Content.Layout>, context: FLRenderContext) {
        apply(configuration: node.configuration, axis: node.axis)
        resetOffsetIfNeeded(for: node.configuration.resetToken)

        contentSize = layout.contentSize
        contentView.flSetFrame(CGRect(origin: .zero, size: layout.contentSize), in: context)
        contentView.update(node: node.content, layout: layout.wrapped, context: context)
    }

    private func apply(configuration: FLScrollConfiguration, axis: FLScrollAxis) {
        let showsIndicators = configuration.indicators == .automatic

        showsVerticalScrollIndicator = showsIndicators && axis.scrollsVertically
        showsHorizontalScrollIndicator = showsIndicators && axis.scrollsHorizontally
        bounces = configuration.bounces
        alwaysBounceVertical = configuration.bounces && axis == .vertical
        alwaysBounceHorizontal = configuration.bounces && axis == .horizontal
        isScrollEnabled = !configuration.isScrollDisabled
        isPagingEnabled = configuration.isPagingEnabled
        keyboardDismissMode = configuration.keyboardDismissMode
        contentInsetAdjustmentBehavior = configuration.contentInsetAdjustmentBehavior
        contentInset = UIEdgeInsets(
            top: configuration.contentInsets.top,
            left: configuration.contentInsets.leading,
            bottom: configuration.contentInsets.bottom,
            right: configuration.contentInsets.trailing
        )
    }

    private func resetOffsetIfNeeded(for token: FLScrollIdentity?) {
        defer {
            appliedToken = token
            hasApplied = true
        }

        guard hasApplied, token != appliedToken else { return }

        setContentOffset(.zero, animated: false)
    }
}
