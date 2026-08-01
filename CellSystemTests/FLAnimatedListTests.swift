import Testing
import UIKit

@testable import CellSystem

private struct Chip: FLView {
    let title: String

    var body: some FLNode {
        FLColor(.systemBlue).frame(width: 120, height: 24)
    }
}

@MainActor
@Suite("Custom node with its own transitions")
struct FLAnimatedListTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private typealias List = FLAnimatedList<String, FLComposed<Chip>>
    private typealias ListView = FLAnimatedListView<String, FLComposed<Chip>>

    private func node(_ ids: [String], animation: FLAnimation = .linear(0.3)) -> List {
        FLAnimatedList(
            items: ids.map { FLListItem(id: $0, node: Chip(title: $0).node) },
            spacing: 8,
            animation: animation
        )
    }

    private func hosted(_ ids: [String]) -> FLHostView<List> {
        let host = FLHostView<List>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(ids, to: host)

        return host
    }

    private func apply(_ ids: [String], to host: FLHostView<List>, animation: FLAnimation = .linear(0.3)) {
        let list = node(ids, animation: animation)
        let layout = list.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: list, layout: layout)
    }

    private func listView(in host: FLHostView<List>) -> ListView? {
        host.subviews.compactMap { $0 as? ListView }.first
    }

    @Test("the custom node lays its items out itself")
    func layoutIsComputedByTheNode() {
        let layout = node(["a", "b", "c"]).layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 120, height: 24 + 8 + 24 + 8 + 24))
        #expect(layout.frames.map(\.minY) == [0, 32, 64])
    }

    @Test("an arriving item animates in from a pre-state")
    func arrivalAnimates() {
        let host = hosted(["a"])
        let list = listView(in: host)

        apply(["a", "b"], to: host)

        let arrived = list?.view(for: "b")

        #expect(arrived != nil)
        #expect(arrived?.layer.animation(forKey: "opacity") != nil)
        #expect(arrived?.layer.animationKeys()?.contains { $0.hasPrefix("position") } == true)
    }

    @Test("a departing item stays in the hierarchy while it animates out")
    func removalIsDeferredByTheNode() {
        let host = hosted(["a", "b"])
        let list = listView(in: host)
        let departing = list?.view(for: "b")

        apply(["a"], to: host)

        #expect(departing?.superview != nil)
        #expect(list?.isAnimatingRemoval == true)
        #expect(departing?.layer.animation(forKey: "opacity") != nil)
    }

    @Test("an item that comes back mid-removal is reclaimed rather than duplicated")
    func returningItemCancelsItsRemoval() {
        let host = hosted(["a", "b"])
        let list = listView(in: host)
        let departing = list?.view(for: "b")

        apply(["a"], to: host)
        #expect(list?.isAnimatingRemoval == true)

        apply(["a", "b"], to: host)

        #expect(list?.isAnimatingRemoval == false)
        #expect(list?.view(for: "b") === departing)
        #expect(departing?.superview != nil)
    }

    @Test("a surviving item animates to its new position")
    func survivorsAnimateToNewPositions() {
        let host = hosted(["a", "b"])
        let list = listView(in: host)
        let survivor = list?.view(for: "b")

        survivor?.layer.removeAllAnimations()
        apply(["x", "a", "b"], to: host)

        #expect(survivor?.layer.animationKeys()?.contains { $0.hasPrefix("position") } == true)
    }

    @Test("the node keeps working inside the rest of the system")
    func composesWithOtherNodes() {
        let composed = node(["a", "b"])
            .padding(12)
            .background(.systemGray6, in: .roundedRectangle(10))
        let layout = composed.layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 144, height: 24 + 8 + 24 + 24))
    }
}
