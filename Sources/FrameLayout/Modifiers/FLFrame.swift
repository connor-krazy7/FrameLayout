import UIKit

public struct FLFrameLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout
    public let wrappedFrame: CGRect
    public let size: CGSize
}

public struct FLFrame<Wrapped: FLNode>: FLNode {
    public typealias View = FLFrameView<Wrapped>

    public static var typeIdentifier: String { "frame(\(Wrapped.typeIdentifier))" }

    public let minWidth: CGFloat?
    public let maxWidth: CGFloat?
    public let minHeight: CGFloat?
    public let maxHeight: CGFloat?
    public let alignment: FLAlignment
    public let wrapped: Wrapped

    public func layout(in context: FLContext) -> FLFrameLayout<Wrapped.Layout> {
        let measuringWidth = Self.childProposal(context.width, min: minWidth, max: maxWidth)
        let measuringHeight = Self.childProposal(context.height, min: minHeight, max: maxHeight)
        let measured = wrapped.layout(in: context.proposing(width: measuringWidth, height: measuringHeight))
        let size = CGSize(
            width: Self.resolvedSize(
                proposal: context.width,
                childSize: measured.size.width,
                min: minWidth,
                max: maxWidth
            ),
            height: Self.resolvedSize(
                proposal: context.height,
                childSize: measured.size.height,
                min: minHeight,
                max: maxHeight
            )
        )
        let placementWidth = Self.placementProposal(
            measuringWidth,
            resolved: size.width,
            measured: measured.size.width,
            isBounded: minWidth != nil || maxWidth != nil
        )
        let placementHeight = Self.placementProposal(
            measuringHeight,
            resolved: size.height,
            measured: measured.size.height,
            isBounded: minHeight != nil || maxHeight != nil
        )
        let placed = placementWidth == measuringWidth && placementHeight == measuringHeight
            ? measured
            : wrapped.layout(in: context.proposing(width: placementWidth, height: placementHeight))

        return FLFrameLayout(
            wrapped: placed,
            wrappedFrame: CGRect(
                origin: alignment.origin(
                    childSize: placed.size,
                    containerSize: size,
                    direction: context.layoutDirection
                ),
                size: placed.size
            ),
            size: size
        )
    }

    /// A bound resolves the frame's own size, and the child then lays out in *that* box rather than in
    /// whatever it answered while being measured — otherwise a bound could only ever crop an oversized
    /// child instead of giving it a smaller box to fit into. Measuring twice is the price; the second
    /// pass is skipped whenever it would ask the same question, which is every unbounded axis and every
    /// bound that did not actually clamp.
    private static func placementProposal(
        _ proposal: FLProposal,
        resolved: CGFloat,
        measured: CGFloat,
        isBounded: Bool
    ) -> FLProposal {
        guard isBounded, resolved != measured else { return proposal }

        return .exact(resolved)
    }

    private static func childProposal(
        _ proposal: FLProposal,
        min lower: CGFloat?,
        max upper: CGFloat?
    ) -> FLProposal {
        switch proposal {
        case let .exact(value):
            .exact(clamp(value, min: lower, max: upper))
        case .unspecified:
            // With nothing proposed from above, only a frame pinned to one value can hand a size
            // down. A bounded one clamps whatever the child answers instead — proposing the bound
            // would inflate a flexible child to it, which is not what maxWidth/maxHeight mean.
            pinned(min: lower, max: upper).map { FLProposal.exact($0) }.or(.unspecified)
        case .minimum, .maximum:
            proposal
        }
    }

    private static func resolvedSize(
        proposal: FLProposal,
        childSize: CGFloat,
        min lower: CGFloat?,
        max upper: CGFloat?
    ) -> CGFloat {
        // Only an exact proposal lets a capped frame grow past its content; every other kind is
        // answering a question about the content itself.
        let base = if upper != nil, let proposed = proposal.exactValue {
            proposed
        } else {
            childSize
        }

        return clamp(base, min: lower, max: upper)
    }

    private static func clamp(_ value: CGFloat, min lower: CGFloat?, max upper: CGFloat?) -> CGFloat {
        let capped = upper.map { Swift.min(value, $0) }.or(value)

        return lower.map { Swift.max(capped, $0) }.or(capped)
    }

    private static func pinned(min lower: CGFloat?, max upper: CGFloat?) -> CGFloat? {
        guard let lower, let upper, lower == upper, lower.isFinite else { return nil }

        return lower
    }
}

public final class FLFrameView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLFrame<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLFrame<Wrapped>, layout: FLFrameLayout<Wrapped.Layout>, context: FLRenderContext) {
        wrappedView.flSetFrame(layout.wrappedFrame, in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

public extension FLNodeProviding {
    func frame(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: FLAlignment = .center
    ) -> FLFrame<ProvidedNode> {
        FLFrame(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            alignment: alignment,
            wrapped: flNode
        )
    }

    func frame(
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: FLAlignment = .center
    ) -> FLFrame<ProvidedNode> {
        FLFrame(
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            maxHeight: maxHeight,
            alignment: alignment,
            wrapped: flNode
        )
    }
}
