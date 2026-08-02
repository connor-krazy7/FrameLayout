import UIKit

struct FLAdjustments: Sendable, Hashable, WithCustomisable {
    var opacity: CGFloat = 1
    var allowsHitTesting: Bool = true

    static func clamped(_ opacity: CGFloat) -> CGFloat {
        Swift.min(1, Swift.max(0, opacity))
    }
}

struct FLAdjustedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLAdjusted<Wrapped: FLNode>: FLNode {
    typealias View = FLAdjustedView<Wrapped>

    static var typeIdentifier: String { "adjusted(\(Wrapped.typeIdentifier))" }

    let adjustments: FLAdjustments
    let wrapped: Wrapped

    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLAdjustedLayout<Wrapped.Layout> {
        FLAdjustedLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLAdjustedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLAdjusted<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLAdjusted<Wrapped>, layout: FLAdjustedLayout<Wrapped.Layout>, context: FLRenderContext) {
        context.perform { self.alpha = node.adjustments.opacity }
        isUserInteractionEnabled = node.adjustments.allowsHitTesting

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

extension FLNodeProviding {
    func adjustments(_ transform: (inout FLAdjustments) -> Void) -> FLAdjusted<ProvidedNode> {
        FLAdjusted(adjustments: FLAdjustments().with(transform), wrapped: flNode)
    }

    func opacity(_ opacity: CGFloat) -> FLAdjusted<ProvidedNode> {
        adjustments { $0.opacity = FLAdjustments.clamped(opacity) }
    }

    func allowsHitTesting(_ allowsHitTesting: Bool) -> FLAdjusted<ProvidedNode> {
        adjustments { $0.allowsHitTesting = allowsHitTesting }
    }
}

extension FLAdjusted {
    func opacity(_ opacity: CGFloat) -> FLAdjusted<Wrapped> {
        let scale = FLAdjustments.clamped(opacity)

        return FLAdjusted(
            adjustments: adjustments.with { $0.opacity *= scale },
            wrapped: wrapped
        )
    }

    func allowsHitTesting(_ allowsHitTesting: Bool) -> FLAdjusted<Wrapped> {
        FLAdjusted(
            adjustments: adjustments.with { $0.allowsHitTesting = $0.allowsHitTesting && allowsHitTesting },
            wrapped: wrapped
        )
    }
}
