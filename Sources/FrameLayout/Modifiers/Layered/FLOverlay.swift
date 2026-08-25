import UIKit

public extension FLNodeProviding {
    func overlay<Overlay: FLNode>(
        _ overlay: Overlay,
        alignment: FLAlignment = .center
    ) -> FLOverlay<ProvidedNode, Overlay> {
        FLOverlay(content: flNode, overlay: overlay, alignment: alignment)
    }

    func overlay<Overlay: FLNode>(
        alignment: FLAlignment = .center,
        @FLNodeBuilder content: () -> Overlay
    ) -> FLOverlay<ProvidedNode, Overlay> {
        FLOverlay(content: flNode, overlay: content(), alignment: alignment)
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
