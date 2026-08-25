import UIKit

public struct FLForEachItem<ID: Hashable & Sendable, Item: FLNode>: Sendable, Hashable {
    public let id: ID
    public let node: Item
}
