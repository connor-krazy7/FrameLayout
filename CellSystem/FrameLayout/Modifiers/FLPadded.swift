import UIKit

struct FLPaddedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout
    let wrappedFrame: CGRect
    let size: CGSize
}

struct FLPadded<Wrapped: FLNode>: FLNode {
    typealias View = FLPaddedView<Wrapped>

    static var typeIdentifier: String { "padded(\(Wrapped.typeIdentifier))" }

    let insets: FLEdgeInsets
    let wrapped: Wrapped

    func layout(in context: FLContext) -> FLPaddedLayout<Wrapped.Layout> {
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

final class FLPaddedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLPadded<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLPadded<Wrapped>, layout: FLPaddedLayout<Wrapped.Layout>, environment: FLEnvironment) {
        wrappedView.frame = layout.wrappedFrame
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, environment: environment)
    }
}

extension FLNode {
    func padding(_ insets: FLEdgeInsets) -> FLPadded<Self> {
        FLPadded(insets: insets, wrapped: self)
    }

    func padding(_ inset: CGFloat) -> FLPadded<Self> {
        padding(FLEdgeInsets.all(inset))
    }

    func padding(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLPadded<Self> {
        padding(FLEdgeInsets.edges(edges, inset))
    }

    func padding(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> FLPadded<Self> {
        padding(FLEdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }
}

extension FLPadded {
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
