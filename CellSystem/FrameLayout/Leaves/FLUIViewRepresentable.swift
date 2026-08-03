import UIKit

struct FLRepresentableLayout: FLLayout {
    let size: CGSize
}

protocol FLUIViewRepresentable: FLNodeProviding, Sendable, Hashable {
    associatedtype ViewType: UIView

    func size(in context: FLContext) -> CGSize

    @MainActor
    func makeView() -> ViewType

    @MainActor
    func update(_ view: ViewType, previous: Self?, context: FLRenderContext)

    @MainActor
    func onDetach(_ view: ViewType)
}

extension FLUIViewRepresentable {
    var flNode: FLRepresentableNode<Self> {
        FLRepresentableNode(content: self)
    }

    @MainActor
    func onDetach(_ view: ViewType) {}
}

struct FLRepresentableNode<Content: FLUIViewRepresentable>: FLNode {
    typealias View = FLRepresentableView<Content>

    static var typeIdentifier: String { "representable(\(Content.self))" }

    let content: Content

    func layout(in context: FLContext) -> FLRepresentableLayout {
        FLRepresentableLayout(size: content.size(in: context))
    }
}

final class FLRepresentableView<Content: FLUIViewRepresentable>: UIView, FLNodeView {
    typealias Node = FLRepresentableNode<Content>

    private var hosted: Content.ViewType?
    private var applied: Content?
    private var hasEnteredWindow = false

    override func layoutSubviews() {
        super.layoutSubviews()

        hosted?.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window == nil else {
            hasEnteredWindow = true

            return
        }

        guard hasEnteredWindow, let hosted, let applied else { return }

        hasEnteredWindow = false
        self.applied = nil
        applied.onDetach(hosted)
    }

    func update(node: FLRepresentableNode<Content>, layout: FLRepresentableLayout, context: FLRenderContext) {
        let view = hostedView(making: node.content)

        node.content.update(view, previous: applied, context: context)
        applied = node.content
    }

    private func hostedView(making content: Content) -> Content.ViewType {
        if let hosted { return hosted }

        let view = content.makeView()

        hosted = view
        view.frame = bounds
        addSubview(view)

        return view
    }
}
