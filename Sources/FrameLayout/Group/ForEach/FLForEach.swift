import UIKit

// MARK: - Group

public struct FLForEach<ID: Hashable & Sendable, Item: FLNode>: FLGroup {
    public typealias Views = FLForEachViews<ID, Item>

    public static var typeIdentifier: String { "forEach(\(Item.typeIdentifier))" }

    public let items: [FLForEachItem<ID, Item>]

    public var childCount: Int { items.count }

    public init(items: [FLForEachItem<ID, Item>]) {
        self.items = items
    }

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        id: KeyPath<Data.Element, ID>,
        @FLNodeBuilder content: (Data.Element) -> Item
    ) {
        items = data.map { element in
            FLForEachItem(id: element[keyPath: id], node: content(element))
        }
    }

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        @FLNodeBuilder content: (Data.Element) -> Item
    ) where Data.Element: Identifiable, Data.Element.ID == ID {
        items = data.map { element in
            FLForEachItem(id: element.id, node: content(element))
        }
    }

    public func layout(in context: FLContext) -> FLGroupChildren {
        layout { _ in context }
    }

    public func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        layout { childContext(childContexts, at: $0) }
    }

    private func layout(context: (Int) -> FLContext) -> FLGroupChildren {
        var children = FLGroupChildren.empty

        for (offset, item) in items.enumerated() {
            let itemLayout = item.node.layout(in: context(offset))

            children = children + FLGroupChildren.single(itemLayout, isSpacer: item.node.isSpacer)
        }

        return children
    }
}

// MARK: - Views

@MainActor
public final class FLForEachViews<ID: Hashable & Sendable, Item: FLNode>: FLGroupViews {
    public typealias Group = FLForEach<ID, Item>

    private var idToView: [ID: Item.View] = [:]

    public init() {}

    public func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        var updated: [UIView] = []
        var reused: [ID: Item.View] = [:]

        updated.reserveCapacity(group.items.count)

        for (offset, item) in group.items.enumerated() {
            guard offset < children.layouts.count,
                  let layout = children.layouts[offset].unwrap(as: Item.Layout.self) else { continue }

            let view = idToView[item.id].or(Item.View())

            view.update(node: item.node, layout: layout, context: context)
            reused[item.id] = view
            updated.append(view)
        }

        for (id, view) in idToView where reused[id] == nil {
            view.removeFromSuperview()
        }

        idToView = reused

        return updated
    }
}
