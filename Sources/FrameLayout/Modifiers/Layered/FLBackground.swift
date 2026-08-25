import UIKit

public extension FLNodeProviding {
    func background<Background: FLNode>(
        _ background: Background,
        alignment: FLAlignment = .center
    ) -> FLBackground<ProvidedNode, Background> {
        FLBackground(content: flNode, background: background, alignment: alignment)
    }

    func background<Background: FLNode>(
        alignment: FLAlignment = .center,
        @FLNodeBuilder content: () -> Background
    ) -> FLBackground<ProvidedNode, Background> {
        FLBackground(content: flNode, background: content(), alignment: alignment)
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
