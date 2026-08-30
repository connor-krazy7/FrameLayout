import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
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

public extension FLAdjusted {
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

// MARK: - Node

public struct FLAdjusted<Wrapped: FLNode>: FLNode {
    public typealias Layout = Wrapped.Layout
    public typealias View = FLAdjustedView<Wrapped>

    public let adjustments: FLAdjustments
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context)
    }
}

// MARK: - FLLayoutEquatable

public extension FLAdjusted {
    func isLayoutEquivalent(to other: FLAdjusted<Wrapped>) -> Bool {
        wrapped.isLayoutEquivalent(to: other.wrapped)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        wrapped.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - View

public final class FLAdjustedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLAdjusted<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLAdjusted<Wrapped>, layout: Wrapped.Layout, context: FLRenderContext) {
        context.perform { self.alpha = node.adjustments.opacity }
        isUserInteractionEnabled = node.adjustments.allowsHitTesting

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout, context: context)
    }
}
