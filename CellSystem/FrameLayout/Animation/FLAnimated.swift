import UIKit

@MainActor
protocol FLFrameApplying: UIView {
    func applyFrame(_ frame: CGRect)
}

extension UIView {
    func flSetFrame(_ frame: CGRect, in context: FLRenderContext) {
        guard let applying = self as? any FLFrameApplying else {
            context.perform { self.frame = frame }

            return
        }

        applying.applyFrame(frame)
    }
}

struct FLAnimatedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLAnimated<Wrapped: FLNode>: FLNode {
    typealias View = FLAnimatedView<Wrapped>

    static var typeIdentifier: String { "animated(\(Wrapped.typeIdentifier))" }

    let animation: FLAnimation?
    let wrapped: Wrapped

    var isEmpty: Bool { wrapped.isEmpty }
    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLAnimatedLayout<Wrapped.Layout> {
        FLAnimatedLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLAnimatedView<Wrapped: FLNode>: FLStructuralView, FLNodeView, FLFrameApplying {
    typealias Node = FLAnimated<Wrapped>

    private let wrappedView = Wrapped.View()
    private var animation: FLAnimation?

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func applyFrame(_ frame: CGRect) {
        guard let animation, self.frame != frame, window != nil else {
            self.frame = frame

            return
        }

        animation.run { self.frame = frame }
    }

    func update(node: FLAnimated<Wrapped>, layout: FLAnimatedLayout<Wrapped.Layout>, context: FLRenderContext) {
        animation = node.animation

        let childContext = context.animating(node.animation)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }
}

extension FLNode {
    func animation(_ animation: FLAnimation?) -> FLAnimated<Self> {
        FLAnimated(animation: animation, wrapped: self)
    }
}
