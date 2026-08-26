import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
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

// MARK: - FLAnimationAlways

public struct FLAnimationAlways: Hashable, Sendable {}

// MARK: - Node

public struct FLAnimated<Wrapped: FLNode, Value: Hashable & Sendable>: FLNode {
    public typealias View = FLAnimatedView<Wrapped, Value>

    public let animation: FLAnimation?
    public let value: Value?
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> FLAnimatedLayout<Wrapped.Layout> {
        FLAnimatedLayout(wrapped: wrapped.layout(in: context))
    }
}

// MARK: - Layout

public struct FLAnimatedLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout

    public var size: CGSize { wrapped.size }
}

// MARK: - View

public final class FLAnimatedView<Wrapped: FLNode, Value: Hashable & Sendable>: FLStructuralView, FLNodeView, FLFrameApplying {
    public typealias Node = FLAnimated<Wrapped, Value>

    private let wrappedView = Wrapped.View()
    private var animation: FLAnimation?
    private var lastValue: Value?

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func applyFrame(_ frame: CGRect) {
        guard let animation, self.frame != frame, window != nil else {
            self.frame = frame

            return
        }

        animation.run { self.frame = frame }
    }

    public func update(node: Node, layout: FLAnimatedLayout<Wrapped.Layout>, context: FLRenderContext) {
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

// MARK: - Optional

public extension Optional {
    fileprivate func filter(_ isIncluded: (Wrapped) -> Bool) -> Wrapped? {
        guard let self, isIncluded(self) else { return nil }

        return self
    }
}
