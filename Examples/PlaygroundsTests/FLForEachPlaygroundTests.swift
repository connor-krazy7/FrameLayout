import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

@MainActor
@Suite("ForEach playground")
struct FLForEachPlaygroundTests {
    private let context = FLContext(width: 300)

    private func demoReactions(_ count: Int) -> [DemoReaction] {
        (0..<count).map { DemoReaction(id: "r\($0)", emoji: "👍", count: $0) }
    }

    private func flattened(_ count: Int, showsHeader: Bool = true) -> CGFloat {
        FlattenedReactions(reactions: demoReactions(count), showsHeader: showsHeader)
            .node.layout(in: context).size.height
    }

    private func nested(_ count: Int, showsHeader: Bool = true) -> CGFloat {
        NestedReactions(reactions: demoReactions(count), showsHeader: showsHeader)
            .node.layout(in: context).size.height
    }

    @Test("a single item lays out the same either way")
    func agreeOnASingleItem() {
        #expect(flattened(1) == nested(1))
    }

    @Test("an empty group still costs a slot when nested, and nothing when flattened")
    func emptyGroupCostsASlotWhenNested() {
        #expect(nested(0) - flattened(0) == 12)
        #expect(flattened(0) == flattened(1) - flattened(1) + flattened(0))
    }

    @Test("each extra item costs the parent's spacing when flattened, the inner spacing when nested")
    func spacingDiffersPerItem() {
        let flattenedStep = flattened(3) - flattened(2)
        let nestedStep = nested(3) - nested(2)

        #expect(flattenedStep - nestedStep == 10)
        #expect(flattened(3) > nested(3))
    }

    @Test("the header is a sibling of the items, not of the group")
    func headerIsASibling() {
        #expect(flattened(2, showsHeader: true) - flattened(2, showsHeader: false) == nested(2, showsHeader: true) - nested(2, showsHeader: false))
    }
}
