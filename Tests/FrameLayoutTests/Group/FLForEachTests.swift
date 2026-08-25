import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("ForEach")
struct FLForEachTests {
    private let context = FLContext(width: 300)

    private func reactions(_ ids: [String]) -> [ForEachReaction] {
        ids.map { ForEachReaction(id: $0, height: 20) }
    }

    private func stack(_ ids: [String]) -> some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLColor(.systemGray4).frame(width: 100, height: 10)

            FLForEach(reactions(ids)) { reaction in
                FLColor(.systemBlue).frame(width: 40, height: reaction.height)
            }

            FLColor(.systemGreen).frame(width: 100, height: 10)
        }
    }

    @Test("items take the parent's spacing, not a nested container's")
    func itemsFlattenIntoTheParent() {
        let height = stack(["a", "b", "c"]).layout(in: context).size.height

        #expect(height == CGFloat(10 + 8 + 20 + 8 + 20 + 8 + 20 + 8 + 10))
    }

    @Test("each item becomes a child of the enclosing stack")
    func itemsBecomeStackChildren() {
        let layout = FLVStack(alignment: .leading, spacing: 8) {
            FLColor(.systemGray4).frame(width: 100, height: 10)

            FLForEach(reactions(["a", "b"])) { reaction in
                FLColor(.systemBlue).frame(width: 40, height: reaction.height)
            }
        }
        .layout(in: context)

        #expect(layout.childFrames.count == 3)
        #expect(layout.childFrames.map(\.minY) == [0, 18, 46])
    }

    @Test("an empty ForEach leaves no gap behind")
    func emptyForEachCostsNothing() {
        #expect(stack([]).layout(in: context).size.height == CGFloat(10 + 8 + 10))
        #expect(stack(["a"]).layout(in: context).size.height == CGFloat(10 + 8 + 20 + 8 + 10))
    }

    @Test("the group reports how many children it contributes")
    func childCountIsReported() {
        let group = FLForEach(reactions(["a", "b", "c"])) { reaction in
            FLColor(.systemBlue).frame(width: 40, height: reaction.height)
        }

        #expect(group.childCount == 3)
        #expect(group.layout(in: context).count == 3)
    }

    @Test("items are keyed by id, so views survive a reorder")
    func viewsAreReusedById() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let host = FLHostView<FLVStack<FLConcat<FLForEach<String, FLFrame<FLColor>>>>>()

        window.addSubview(host)

        func apply(_ ids: [String]) {
            let node = FLVStack(alignment: .leading, spacing: 8) {
                FLForEach(reactions(ids)) { reaction in
                    FLColor(.systemBlue).frame(width: 40, height: reaction.height)
                }
            }
            let layout = node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(["a", "b"])

        let stackView = host.subviews.first
        let firstRound = stackView?.subviews

        apply(["b", "a"])

        let secondRound = stackView?.subviews

        #expect(firstRound?.count == 2)
        #expect(secondRound?.count == 2)
        #expect(Set(secondRound?.map(ObjectIdentifier.init) ?? []) == Set(firstRound?.map(ObjectIdentifier.init) ?? []))
    }

    @Test("a removed item's view leaves the hierarchy")
    func removedItemsAreDetached() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let host = FLHostView<FLVStack<FLConcat<FLForEach<String, FLFrame<FLColor>>>>>()

        window.addSubview(host)

        func apply(_ ids: [String]) {
            let node = FLVStack(alignment: .leading, spacing: 8) {
                FLForEach(reactions(ids)) { reaction in
                    FLColor(.systemBlue).frame(width: 40, height: reaction.height)
                }
            }
            let layout = node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(["a", "b", "c"])
        let stackView = host.subviews.first
        #expect(stackView?.subviews.count == 3)

        apply(["a", "c"])
        #expect(stackView?.subviews.count == 2)
    }

    @Test("a ForEach sits alongside a conditional in the same stack")
    func composesWithConditionals() {
        func node(showsHeader: Bool, ids: [String]) -> some FLNode {
            FLVStack(alignment: .leading, spacing: 8) {
                if showsHeader {
                    FLColor(.systemGray4).frame(width: 100, height: 10)
                }

                FLForEach(reactions(ids)) { reaction in
                    FLColor(.systemBlue).frame(width: 40, height: reaction.height)
                }
            }
        }

        #expect(node(showsHeader: true, ids: ["a"]).layout(in: context).size.height == CGFloat(10 + 8 + 20))
        #expect(node(showsHeader: false, ids: ["a"]).layout(in: context).size.height == 20)
        #expect(node(showsHeader: false, ids: []).layout(in: context).size.height == 0)
    }

    @Test("a spacer inside a ForEach still absorbs slack from the parent")
    func spacerInsideForEachStillWorks() {
        let node = FLVStack(spacing: 0) {
            FLColor(.systemGray4).frame(width: 100, height: 10)

            FLForEach([ForEachReaction(id: "gap", height: 0)]) { _ in
                FLSpacer()
            }

            FLColor(.systemGreen).frame(width: 100, height: 10)
        }
        let layout = node.layout(in: FLContext(width: 300, height: 100))

        #expect(layout.size.height == 100)
        #expect(layout.childFrames[2].minY == 90)
    }
}
