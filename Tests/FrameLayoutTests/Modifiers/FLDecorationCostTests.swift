import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Decoration cost")
struct FLDecorationCostTests {
    private let context = FLContext(width: 200)

    private func bubble(radius: CGFloat) -> FLDecorated<FLPadded<FLText>> {
        FLText("a bubble whose corner radius is the only thing that differs")
            .padding(10)
            .background(.systemBlue, in: .roundedRectangle(radius))
    }

    @Test("a corner radius does not change any size")
    func radiusIsLayoutNeutral() {
        #expect(bubble(radius: 4).layout(in: context).size == bubble(radius: 20).layout(in: context).size)
    }

    @Test("but it does change node identity, so a cache keyed on the node misses")
    func radiusInvalidatesTheCache() {
        let cache = FLLayoutCache<FLDecorated<FLPadded<FLText>>>()

        _ = cache.layout(for: bubble(radius: 4), in: context)

        #expect(cache.count == 1)

        _ = cache.layout(for: bubble(radius: 4), in: context)

        #expect(cache.count == 1)

        _ = cache.layout(for: bubble(radius: 20), in: context)

        #expect(cache.count == 2)
        #expect(bubble(radius: 4) != bubble(radius: 20))
    }

    @Test("corner selection is applied at update, so two corner sets produce equal layouts")
    func cornerSelectionIsLayoutNeutral() {
        let all = FLText("x").background(.systemBlue, in: .roundedRectangle(8)).layout(in: context)
        let top = FLText("x")
            .background(.systemBlue, in: .roundedRectangle(8), corners: .top)
            .layout(in: context)

        #expect(all == top)
        #expect(all.size == top.size)
    }

    @Test("a decoration reports its child's layout unchanged")
    func decorationIsLayoutTransparent() {
        let undecorated = FLText("a bubble").padding(10)
        let decorated = undecorated.background(.systemBlue, in: .roundedRectangle(16))

        #expect(decorated.layout(in: context) == undecorated.layout(in: context))
    }
}
