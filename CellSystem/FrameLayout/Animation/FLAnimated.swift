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

struct FLAnimationAlways: Hashable, Sendable {}

struct FLAnimated<Wrapped: FLNode, Value: Hashable & Sendable>: FLNode {
    typealias View = FLAnimatedView<Wrapped, Value>

    static var typeIdentifier: String { "animated(\(Wrapped.typeIdentifier))" }

    let animation: FLAnimation?
    let value: Value?
    let wrapped: Wrapped

    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLAnimatedLayout<Wrapped.Layout> {
        FLAnimatedLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLAnimatedView<Wrapped: FLNode, Value: Hashable & Sendable>: FLStructuralView, FLNodeView, FLFrameApplying {
    typealias Node = FLAnimated<Wrapped, Value>

    private let wrappedView = Wrapped.View()
    private var animation: FLAnimation?
    private var lastValue: Value?

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

    func update(node: Node, layout: FLAnimatedLayout<Wrapped.Layout>, context: FLRenderContext) {
        let effectiveAnimation = node.animation.filter { _ in shouldAnimate(for: node.value) }

        animation = effectiveAnimation

        let childContext = context.animating(effectiveAnimation)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }

    private func shouldAnimate(for value: Value?) -> Bool {
        guard let value else { return true }

        let previous = lastValue
        lastValue = value

        guard let previous else { return false }

        return previous != value
    }
}

extension Optional {
    fileprivate func filter(_ isIncluded: (Wrapped) -> Bool) -> Wrapped? {
        guard let self, isIncluded(self) else { return nil }

        return self
    }
}

extension FLNodeProviding {
    func animation(_ animation: FLAnimation?) -> FLAnimated<ProvidedNode, FLAnimationAlways> {
        FLAnimated(animation: animation, value: nil, wrapped: flNode)
    }

    func animation<Value: Hashable & Sendable>(
        _ animation: FLAnimation?,
        value: Value
    ) -> FLAnimated<ProvidedNode, Value> {
        FLAnimated(animation: animation, value: value, wrapped: flNode)
    }
}
