import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
    func padding(_ insets: FLEdgeInsets) -> FLPadded<ProvidedNode> {
        FLPadded(insets: insets, wrapped: flNode)
    }

    func padding(_ inset: CGFloat) -> FLPadded<ProvidedNode> {
        padding(FLEdgeInsets.all(inset))
    }

    func padding(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLPadded<ProvidedNode> {
        padding(FLEdgeInsets.edges(edges, inset))
    }

    func padding(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> FLPadded<ProvidedNode> {
        padding(FLEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }
}

public extension FLPadded {
    func padding(_ insets: FLEdgeInsets) -> FLPadded<Wrapped> {
        FLPadded(insets: self.insets.adding(insets), wrapped: wrapped)
    }

    func padding(_ inset: CGFloat) -> FLPadded<Wrapped> {
        padding(FLEdgeInsets.all(inset))
    }

    func padding(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLPadded<Wrapped> {
        padding(FLEdgeInsets.edges(edges, inset))
    }

    func padding(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> FLPadded<Wrapped> {
        padding(FLEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }
}

// MARK: - Node

public struct FLPadded<Wrapped: FLNode>: FLNode {
    public typealias View = FLPaddedView<Wrapped>

    public static var typeIdentifier: String { "padded(\(Wrapped.typeIdentifier))" }

    public let insets: FLEdgeInsets
    public let wrapped: Wrapped

    public func layout(in context: FLContext) -> FLPaddedLayout<Wrapped.Layout> {
        let wrappedLayout = wrapped.layout(in: context.inset(by: insets))

        return FLPaddedLayout(
            wrapped: wrappedLayout,
            wrappedFrame: CGRect(
                origin: CGPoint(x: insets.left(in: context.layoutDirection), y: insets.top),
                size: wrappedLayout.size
            ),
            size: CGSize(
                width: wrappedLayout.size.width + insets.horizontal,
                height: wrappedLayout.size.height + insets.vertical
            )
        )
    }
}

// MARK: - Layout

public struct FLPaddedLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout
    public let wrappedFrame: CGRect
    public let size: CGSize
}

// MARK: - View

public final class FLPaddedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLPadded<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLPadded<Wrapped>, layout: FLPaddedLayout<Wrapped.Layout>, context: FLRenderContext) {
        wrappedView.flSetFrame(layout.wrappedFrame, in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}
