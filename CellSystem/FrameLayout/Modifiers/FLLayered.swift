import UIKit

struct FLLayeredLayout<PrimaryLayout: FLLayout, SecondaryLayout: FLLayout>: FLLayout {
    let primary: PrimaryLayout
    let secondary: SecondaryLayout
    let secondaryFrame: CGRect

    var size: CGSize { primary.size }
}

enum FLLayered {
    static func layout<Primary: FLNode, Secondary: FLNode>(
        primary: Primary,
        secondary: Secondary,
        alignment: FLAlignment,
        in context: FLContext
    ) -> FLLayeredLayout<Primary.Layout, Secondary.Layout> {
        let primaryLayout = primary.layout(in: context)
        let secondaryLayout = secondary.layout(
            in: context.proposing(
                width: .exact(primaryLayout.size.width),
                height: .exact(primaryLayout.size.height)
            )
        )

        return FLLayeredLayout(
            primary: primaryLayout,
            secondary: secondaryLayout,
            secondaryFrame: CGRect(
                origin: alignment.origin(
                    childSize: secondaryLayout.size,
                    containerSize: primaryLayout.size,
                    direction: context.layoutDirection
                ),
                size: secondaryLayout.size
            )
        )
    }
}

struct FLBackground<Content: FLNode, Background: FLNode>: FLNode {
    typealias View = FLBackgroundView<Content, Background>

    static var typeIdentifier: String {
        "background(\(Content.typeIdentifier),\(Background.typeIdentifier))"
    }

    let content: Content
    let background: Background
    let alignment: FLAlignment

    func layout(in context: FLContext) -> FLLayeredLayout<Content.Layout, Background.Layout> {
        FLLayered.layout(primary: content, secondary: background, alignment: alignment, in: context)
    }
}

final class FLBackgroundView<Content: FLNode, Background: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLBackground<Content, Background>

    private let backgroundView = Background.View()
    private let contentView = Content.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundView)
        addSubview(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLLayeredLayout<Content.Layout, Background.Layout>, context: FLRenderContext) {
        backgroundView.frame = layout.secondaryFrame
        backgroundView.update(node: node.background, layout: layout.secondary, context: context)

        contentView.frame = CGRect(origin: .zero, size: layout.primary.size)
        contentView.update(node: node.content, layout: layout.primary, context: context)
    }
}

struct FLOverlay<Content: FLNode, Overlay: FLNode>: FLNode {
    typealias View = FLOverlayView<Content, Overlay>

    static var typeIdentifier: String {
        "overlay(\(Content.typeIdentifier),\(Overlay.typeIdentifier))"
    }

    let content: Content
    let overlay: Overlay
    let alignment: FLAlignment

    func layout(in context: FLContext) -> FLLayeredLayout<Content.Layout, Overlay.Layout> {
        FLLayered.layout(primary: content, secondary: overlay, alignment: alignment, in: context)
    }
}

final class FLOverlayView<Content: FLNode, Overlay: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLOverlay<Content, Overlay>

    private let contentView = Content.View()
    private let overlayView = Overlay.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(contentView)
        addSubview(overlayView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLLayeredLayout<Content.Layout, Overlay.Layout>, context: FLRenderContext) {
        contentView.frame = CGRect(origin: .zero, size: layout.primary.size)
        contentView.update(node: node.content, layout: layout.primary, context: context)

        overlayView.frame = layout.secondaryFrame
        overlayView.update(node: node.overlay, layout: layout.secondary, context: context)
    }
}

extension FLNode {
    func background<Background: FLNode>(
        _ background: Background,
        alignment: FLAlignment = .center
    ) -> FLBackground<Self, Background> {
        FLBackground(content: self, background: background, alignment: alignment)
    }

    func overlay<Overlay: FLNode>(
        _ overlay: Overlay,
        alignment: FLAlignment = .center
    ) -> FLOverlay<Self, Overlay> {
        FLOverlay(content: self, overlay: overlay, alignment: alignment)
    }
}
