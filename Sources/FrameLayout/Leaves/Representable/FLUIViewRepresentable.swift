import UIKit

public protocol FLUIViewRepresentable: FLNodeProviding, Sendable, Hashable {
    associatedtype ViewType: UIView

    func size(in context: FLContext) -> CGSize

    @MainActor
    func makeView() -> ViewType

    @MainActor
    func update(_ view: ViewType, previous: Self?, context: FLRenderContext)

    @MainActor
    func onDetach(_ view: ViewType)
}

public extension FLUIViewRepresentable {
    var flNode: FLRepresentableNode<Self> {
        FLRepresentableNode(content: self)
    }

    @MainActor
    func onDetach(_ view: ViewType) {}
}
