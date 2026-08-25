import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Fixture composites")
struct FLFixtureCompositeTests {
    private let context = FLContext(width: 320)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))

    private func height(_ item: FixtureItem) -> CGFloat {
        FixtureRow(item: item).node.layout(in: context).size.height
    }

    private func hosted(_ item: FixtureItem) -> FLHost<FixtureRow> {
        let host = FLHost<FixtureRow>()
        let node = FixtureRow(item: item).node
        let layout = node.layout(in: context)

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("a four-level composite tree measures to something sane")
    func treeMeasures() {
        let size = FixtureRow(item: FixtureItem.sample).node.layout(in: context).size

        #expect(size.width > 0)
        #expect(size.height > 40)
        #expect(size.width <= 320)
    }

    @Test("nested data drives the size: each badge widens the strip without changing the height")
    func badgesWidenTheStrip() {
        let item = FixtureItem.sample
        let two = FixtureBadges(badges: ["one", "two"], id: item.id).node.layout(in: context).size
        let four = FixtureBadges(badges: ["one", "two", "three", "four"], id: item.id).node.layout(in: context).size

        #expect(four.width > two.width)
        #expect(four.height == two.height)
    }

    @Test("an optional detail line only costs height when the data has one")
    func detailIsConditional() {
        let without = height(FixtureItem.sample.with(detail: nil))
        let with = height(FixtureItem.sample.with(detail: "and the data is nested to match"))

        #expect(with > without)
    }

    @Test("parts nested three composites deep are still reachable by tag")
    func deepPartsAreTagged() {
        let host = hosted(FixtureItem.sample.with(isFlagged: true))
        let id = FixtureItem.sample.id

        #expect(host.registry.containsView(withTag: FixturePart.avatar(id)))
        #expect(host.registry.containsView(withTag: FixturePart.title(id)))
        #expect(host.registry.containsView(withTag: FixturePart.badges(id)))
        #expect(host.registry.button(withTag: FixturePart.flag(id)) != nil)
    }

    @Test("the flag button exists only while the data says so")
    func flagFollowsTheData() {
        let id = FixtureItem.sample.id

        #expect(hosted(FixtureItem.sample.with(isFlagged: true)).registry.button(withTag: FixturePart.flag(id)) != nil)
        #expect(hosted(FixtureItem.sample.with(isFlagged: false)).registry.button(withTag: FixturePart.flag(id)) == nil)
    }

    @Test("a binding declared once survives the button coming and going")
    func bindingSurvivesReappearance() {
        let host = FLHost<FixtureRow>()
        let id = FixtureItem.sample.id
        var taps = 0

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindAction(withTag: FixturePart.flag(id)) { _ in taps += 1 }

        func apply(isFlagged: Bool) {
            let node = FixtureRow(item: FixtureItem.sample.with(isFlagged: isFlagged)).node
            let layout = node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(isFlagged: false)
        apply(isFlagged: true)
        host.registry.button(withTag: FixturePart.flag(id))?.sendActions(for: .touchUpInside)

        apply(isFlagged: false)
        apply(isFlagged: true)
        host.registry.button(withTag: FixturePart.flag(id))?.sendActions(for: .touchUpInside)

        #expect(taps == 2)
    }

    @Test("equal nested data produces equal nodes, so the cache can key on them")
    func nestedEqualityHolds() {
        let first = FixtureRow(item: FixtureItem.sample).node
        let second = FixtureRow(item: FixtureItem.sample).node
        let different = FixtureRow(item: FixtureItem.sample.with(badges: ["one"])).node

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first != different)
    }
}
