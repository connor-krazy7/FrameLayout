import UIKit

struct FLFrameLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout
    let wrappedFrame: CGRect
    let size: CGSize
}

struct FLFrame<Wrapped: FLNode>: FLNode {
    typealias View = FLFrameView<Wrapped>

    static var typeIdentifier: String { "frame(\(Wrapped.typeIdentifier))" }

    let minWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let maxHeight: CGFloat?
    let alignment: FLAlignment
    let wrapped: Wrapped

    func layout(in context: FLContext) -> FLFrameLayout<Wrapped.Layout> {
        let wrappedLayout = wrapped.layout(
            in: context.proposing(
                width: Self.childProposal(context.width, min: minWidth, max: maxWidth),
                height: Self.childProposal(context.height, min: minHeight, max: maxHeight)
            )
        )
        let size = CGSize(
            width: Self.resolvedSize(
                proposal: context.width,
                childSize: wrappedLayout.size.width,
                min: minWidth,
                max: maxWidth
            ),
            height: Self.resolvedSize(
                proposal: context.height,
                childSize: wrappedLayout.size.height,
                min: minHeight,
                max: maxHeight
            )
        )

        return FLFrameLayout(
            wrapped: wrappedLayout,
            wrappedFrame: CGRect(
                origin: alignment.origin(
                    childSize: wrappedLayout.size,
                    containerSize: size,
                    direction: context.layoutDirection
                ),
                size: wrappedLayout.size
            ),
            size: size
        )
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
            // A constrained frame still bounds its child even with nothing proposed from above.
            finite(upper).or(lower).map { .exact(clamp($0, min: lower, max: upper)) }.or(.unspecified)
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

    private static func finite(_ value: CGFloat?) -> CGFloat? {
        value.flatMap { $0.isFinite ? $0 : nil }
    }
}

final class FLFrameView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLFrame<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLFrame<Wrapped>, layout: FLFrameLayout<Wrapped.Layout>, environment: FLEnvironment) {
        wrappedView.frame = layout.wrappedFrame
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, environment: environment)
    }
}

extension FLNode {
    func frame(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        alignment: FLAlignment = .center
    ) -> FLFrame<Self> {
        FLFrame(
            minWidth: width,
            maxWidth: width,
            minHeight: height,
            maxHeight: height,
            alignment: alignment,
            wrapped: self
        )
    }

    func frame(
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: FLAlignment = .center
    ) -> FLFrame<Self> {
        FLFrame(
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            maxHeight: maxHeight,
            alignment: alignment,
            wrapped: self
        )
    }
}
