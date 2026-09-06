import UIKit

// MARK: - Node

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

// MARK: - FLLayoutEquatable

public extension FLScroll {
    func isLayoutEquivalent(to other: FLScroll<Content>) -> Bool {
        axis == other.axis
            && configuration.isLayoutEquivalent(to: other.configuration)
            && content.isLayoutEquivalent(to: other.content)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(axis)
        configuration.hashLayoutIdentity(into: &hasher)
        content.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - Modifiers

public extension FLScroll {
    /// Where the region starts. Applied on this view's first apply and never again, so it is only safe
    /// where the host is not recycled — a sheet or a detail screen. In a reused cell pass a `contentID:`,
    /// or a recycled view keeps whatever position the previous item left behind.
    func scrollAnchor(_ anchor: FLScrollAnchor) -> FLScroll {
        configured { $0.initialAnchor = anchor }
    }

    /// Applied whenever `contentID` changes, so each content gets its own starting position: the top by
    /// default, or a stored one, which is how a gallery comes back where it was left. Within one content it
    /// is applied exactly once: an anchor is where a content starts, not a position it is held at.
    func scrollAnchor(
        _ anchor: FLScrollAnchor,
        contentID: some Hashable & Sendable
    ) -> FLScroll {
        configured {
            $0.initialAnchor = anchor
            $0.contentID = FLScrollIdentity(contentID)
        }
    }

    /// `scrollAnchor(.offset(_:))`, spelled for a position that is a point.
    func initialContentOffset(_ offset: FLPoint) -> FLScroll {
        scrollAnchor(.offset(offset))
    }

    func initialContentOffset(
        _ offset: FLPoint = .zero,
        contentID: some Hashable & Sendable
    ) -> FLScroll {
        scrollAnchor(.offset(offset), contentID: contentID)
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

// MARK: - Layout

public struct FLScrollLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout
    public let contentSize: CGSize
    public let size: CGSize
}

// MARK: - View

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

        contentSize = layout.contentSize
        contentView.flSetFrame(CGRect(origin: .zero, size: layout.contentSize), in: context)
        contentView.update(node: node.content, layout: layout.wrapped, context: context)

        applyInitialOffsetIfContentChanged(
            configuration: node.configuration,
            viewport: layout.size,
            context: context
        )
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

    /// After `contentSize` and after the content has updated, never before: `UIScrollView` clamps an offset
    /// to the content it knows about, so a position set while the content is still empty is silently lost,
    /// and an `.element` anchor reads a descendant that only exists once the subtree has registered itself.
    private func applyInitialOffsetIfContentChanged(
        configuration: FLScrollConfiguration,
        viewport: CGSize,
        context: FLRenderContext
    ) {
        let token = configuration.contentID

        defer {
            appliedToken = token
            hasApplied = true
        }

        guard !hasApplied || token != appliedToken else { return }

        setContentOffset(
            offset(for: configuration.initialAnchor, viewport: viewport, context: context),
            animated: false
        )
    }

    private func offset(
        for anchor: FLScrollAnchor,
        viewport: CGSize,
        context: FLRenderContext
    ) -> CGPoint {
        switch anchor {
        case let .offset(offset):
            offset.cgPoint
        case let .element(id, alignment):
            offset(showing: id, alignedTo: alignment, viewport: viewport, context: context)
        }
    }

    private func offset(
        showing id: FLScrollIdentity,
        alignedTo alignment: FLAlignment,
        viewport: CGSize,
        context: FLRenderContext
    ) -> CGPoint {
        // A registry is per host, not per region, so a tag used elsewhere in the tree must not resolve here.
        guard
            let element = context.registry?.view(withTag: id.tag),
            element.isDescendant(of: contentView)
        else { return .zero }

        let elementFrame = convert(element.bounds, from: element)
        let originInViewport = alignment.origin(
            childSize: elementFrame.size,
            containerSize: viewport,
            direction: context.environment.layoutDirection
        )
        let aligned = CGPoint(
            x: elementFrame.minX - originInViewport.x,
            y: elementFrame.minY - originInViewport.y
        )

        return clampedToContent(aligned, viewport: viewport)
    }

    private func clampedToContent(_ offset: CGPoint, viewport: CGSize) -> CGPoint {
        let insets = adjustedContentInset
        let maximumX = contentSize.width - viewport.width + insets.right
        let maximumY = contentSize.height - viewport.height + insets.bottom

        return CGPoint(
            x: Self.clamp(offset.x, min: -insets.left, max: maximumX),
            y: Self.clamp(offset.y, min: -insets.top, max: maximumY)
        )
    }

    /// The floor wins where the two cross, which is every axis whose content is shorter than its viewport.
    private static func clamp(_ value: CGFloat, min lower: CGFloat, max upper: CGFloat) -> CGFloat {
        Swift.max(lower, Swift.min(value, upper))
    }
}
