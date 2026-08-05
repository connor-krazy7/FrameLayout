import Testing
import UIKit

@testable import FrameLayout

@Suite("Opacity and hit-test adjustments")
struct FLAdjustedTests {
    private let context = FLContext(width: 300)

    @Test("adjustments do not change layout")
    func layoutIsUnaffected() {
        let content = FLColor(.red).frame(width: 40, height: 20)
        let adjusted = content.opacity(0.3).allowsHitTesting(false)

        #expect(adjusted.layout(in: context).size == content.layout(in: context).size)
    }

    @Test("chained adjustments collapse into one node")
    func chainingMerges() {
        let once: FLAdjusted<FLText> = FLText("x").opacity(0.5)
        let twice: FLAdjusted<FLText> = FLText("x").opacity(0.5).allowsHitTesting(false)

        #expect(once.adjustments.opacity == 0.5)
        #expect(twice.adjustments.opacity == 0.5)
        #expect(twice.adjustments.allowsHitTesting == false)
    }

    @Test("nested opacities multiply")
    func opacityMultiplies() {
        let node = FLText("x").opacity(0.5).opacity(0.5)

        #expect(node.adjustments.opacity == 0.25)
    }

    @Test("opacity is clamped to a usable range")
    func opacityIsClamped() {
        #expect(FLText("x").opacity(4).adjustments.opacity == 1)
        #expect(FLText("x").opacity(-2).adjustments.opacity == 0)
    }

    @Test("a disabled subtree cannot opt back in")
    func hitTestingDoesNotReEnable() {
        let node = FLText("x").allowsHitTesting(false).allowsHitTesting(true)

        #expect(node.adjustments.allowsHitTesting == false)
    }

    @Test("adjustments take part in equality and hashing")
    func adjustmentsAreDistinguished() {
        let base = FLText("x").opacity(0.5)

        #expect(base == FLText("x").opacity(0.5))
        #expect(base != FLText("x").opacity(0.6))
        #expect(base.hashValue != FLText("x").opacity(0.6).hashValue)
    }
}
