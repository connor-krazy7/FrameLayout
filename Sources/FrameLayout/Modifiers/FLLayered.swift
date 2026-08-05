import UIKit

public struct FLLayeredLayout<PrimaryLayout: FLLayout, SecondaryLayout: FLLayout>: FLLayout {
    public let primary: PrimaryLayout
    public let secondary: SecondaryLayout
    public let secondaryFrame: CGRect

    public var size: CGSize { primary.size }
}

public enum FLLayered {
    public static func layout<Primary: FLNode, Secondary: FLNode>(
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

public struct FLBackground<Content: FLNode, Background: FLNode>: FLNode {
    public typealias View = FLBackgroundView<Content, Background>

    public static var typeIdentifier: String {
        "background(\(Content.typeIdentifier),\(Background.typeIdentifier))"
    }

    public let content: Content
    public let background: Background
    public let alignment: FLAlignment

    public func layout(in context: FLContext) -> FLLayeredLayout<Content.Layout, Background.Layout> {
        FLLayered.layout(primary: content, secondary: background, alignment: alignment, in: context)
    }
}

public final class FLBackgroundView<Content: FLNode, Background: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLBackground<Content, Background>

    private let backgroundView = Background.View()
    private let contentView = Content.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(backgroundView)
        addSubview(contentView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: FLLayeredLayout<Content.Layout, Background.Layout>, context: FLRenderContext) {
        backgroundView.flSetFrame(layout.secondaryFrame, in: context)
        backgroundView.update(node: node.background, layout: layout.secondary, context: context)

        contentView.flSetFrame(CGRect(origin: .zero, size: layout.primary.size), in: context)
        contentView.update(node: node.content, layout: layout.primary, context: context)
    }
}

public struct FLOverlay<Content: FLNode, Overlay: FLNode>: FLNode {
    public typealias View = FLOverlayView<Content, Overlay>

    public static var typeIdentifier: String {
        "overlay(\(Content.typeIdentifier),\(Overlay.typeIdentifier))"
    }

    public let content: Content
    public let overlay: Overlay
    public let alignment: FLAlignment

    public func layout(in context: FLContext) -> FLLayeredLayout<Content.Layout, Overlay.Layout> {
        FLLayered.layout(primary: content, secondary: overlay, alignment: alignment, in: context)
    }
}

public final class FLOverlayView<Content: FLNode, Overlay: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLOverlay<Content, Overlay>

    private let contentView = Content.View()
    private let overlayView = Overlay.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(contentView)
        addSubview(overlayView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: FLLayeredLayout<Content.Layout, Overlay.Layout>, context: FLRenderContext) {
        contentView.flSetFrame(CGRect(origin: .zero, size: layout.primary.size), in: context)
        contentView.update(node: node.content, layout: layout.primary, context: context)

        overlayView.flSetFrame(layout.secondaryFrame, in: context)
        overlayView.update(node: node.overlay, layout: layout.secondary, context: context)
    }
}

public extension FLNodeProviding {
    func background<Background: FLNode>(
        _ background: Background,
        alignment: FLAlignment = .center
    ) -> FLBackground<ProvidedNode, Background> {
        FLBackground(content: flNode, background: background, alignment: alignment)
    }

    func overlay<Overlay: FLNode>(
        _ overlay: Overlay,
        alignment: FLAlignment = .center
    ) -> FLOverlay<ProvidedNode, Overlay> {
        FLOverlay(content: flNode, overlay: overlay, alignment: alignment)
    }

    func background<Background: FLNode>(
        alignment: FLAlignment = .center,
        @FLNodeBuilder content: () -> Background
    ) -> FLBackground<ProvidedNode, Background> {
        FLBackground(content: flNode, background: content(), alignment: alignment)
    }

    func overlay<Overlay: FLNode>(
        alignment: FLAlignment = .center,
        @FLNodeBuilder content: () -> Overlay
    ) -> FLOverlay<ProvidedNode, Overlay> {
        FLOverlay(content: flNode, overlay: content(), alignment: alignment)
    }
}
