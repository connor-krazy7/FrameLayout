import FrameLayout
import UIKit

struct FLListItem<ID: Hashable & Sendable, Item: FLNode>: Hashable, Sendable {
    let id: ID
    let node: Item
}

struct FLAnimatedListLayout<ItemLayout: FLLayout>: FLLayout {
    let items: [ItemLayout]
    let frames: [CGRect]
    let size: CGSize
}

struct FLAnimatedList<ID: Hashable & Sendable, Item: FLNode>: FLNode {
    typealias View = FLAnimatedListView<ID, Item>

    static var typeIdentifier: String { "animatedList(\(Item.typeIdentifier))" }

    let items: [FLListItem<ID, Item>]
    let spacing: CGFloat
    let animation: FLAnimation

    init(items: [FLListItem<ID, Item>], spacing: CGFloat = 8, animation: FLAnimation = .easeInOut(0.3)) {
        self.items = items
        self.spacing = spacing
        self.animation = animation
    }

    func layout(in context: FLContext) -> FLAnimatedListLayout<Item.Layout> {
        var itemLayouts: [Item.Layout] = []
        var frames: [CGRect] = []
        var offsetY: CGFloat = 0
        var width: CGFloat = 0

        for item in items {
            let itemLayout = item.node.layout(in: context)

            itemLayouts.append(itemLayout)
            frames.append(CGRect(origin: CGPoint(x: 0, y: offsetY), size: itemLayout.size))
            offsetY += itemLayout.size.height + spacing
            width = max(width, itemLayout.size.width)
        }

        return FLAnimatedListLayout(
            items: itemLayouts,
            frames: frames,
            size: CGSize(width: width, height: max(0, offsetY - (items.isEmpty ? 0 : spacing)))
        )
    }
}

final class FLAnimatedListView<ID: Hashable & Sendable, Item: FLNode>: UIView, FLNodeView {
    typealias Node = FLAnimatedList<ID, Item>

    private var idToView: [ID: Item.View] = [:]
    private var presentIds: [ID] = []
    private var leavingIds: Set<ID> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isAnimatingRemoval: Bool { !leavingIds.isEmpty }

    func view(for id: ID) -> UIView? { idToView[id] }

    func update(node: Node, layout: FLAnimatedListLayout<Item.Layout>, context: FLRenderContext) {
        let arriving = Set(node.items.map(\.id)).subtracting(presentIds)
        let leaving = Set(presentIds).subtracting(node.items.map(\.id))

        for (index, item) in node.items.enumerated() {
            place(item, at: layout.frames[index], layout: layout.items[index], isNew: arriving.contains(item.id), node: node, context: context)
        }

        for id in leaving {
            remove(id, animation: node.animation)
        }

        presentIds = node.items.map(\.id)
    }

    private func place(
        _ item: FLListItem<ID, Item>,
        at frame: CGRect,
        layout: Item.Layout,
        isNew: Bool,
        node: Node,
        context: FLRenderContext
    ) {
        let itemView = idToView[item.id].or(Item.View())

        idToView[item.id] = itemView

        if itemView.superview !== self {
            addSubview(itemView)
        }

        let wasLeaving = leavingIds.remove(item.id) != nil

        if isNew, !wasLeaving {
            itemView.alpha = 0
            itemView.frame = frame.offsetBy(dx: -frame.width / 4, dy: 0)
        }

        itemView.update(node: item.node, layout: layout, context: context)

        node.animation.run {
            itemView.alpha = 1
            itemView.frame = frame
        }
    }

    private func remove(_ id: ID, animation: FLAnimation) {
        guard let itemView = idToView[id], !leavingIds.contains(id) else { return }

        leavingIds.insert(id)

        animation.run {
            itemView.alpha = 0
            itemView.frame = itemView.frame.offsetBy(dx: -itemView.frame.width / 4, dy: 0)
        } completion: { [weak self] _ in
            guard let self, leavingIds.remove(id) != nil else { return }

            itemView.removeFromSuperview()
            idToView[id] = nil
        }
    }
}
