import UIKit

public protocol FLLayout: Sendable, Equatable {
    var size: CGSize { get }
}

public protocol FLNodeProviding {
    associatedtype ProvidedNode: FLNode

    var flNode: ProvidedNode { get }
}

public protocol FLNode: FLNodeProviding, Sendable, Hashable {
    associatedtype Layout: FLLayout
    associatedtype View: FLNodeView where View.Node == Self

    static var typeIdentifier: String { get }

    var isSpacer: Bool { get }

    func layout(in context: FLContext) -> Layout
}

public extension FLNode {
    static var typeIdentifier: String { String(reflecting: Self.self) }

    var isSpacer: Bool { false }

    var flNode: Self { self }
}

@MainActor
public protocol FLNodeView: UIView {
    associatedtype Node: FLNode

    init()

    func update(node: Node, layout: Node.Layout, context: FLRenderContext)
}
