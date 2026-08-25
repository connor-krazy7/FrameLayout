import Testing
import UIKit
@testable import FrameLayout

@Suite("FLFrame sizing")
struct FLFrameTests {
    private func width(
        minWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        childWidth: CGFloat,
        proposal: CGFloat?
    ) -> CGFloat {
        FLColor(.clear)
            .frame(width: childWidth, height: 10)
            .frame(minWidth: minWidth, maxWidth: maxWidth)
            .layout(in: FLContext(width: proposal))
            .size
            .width
    }

    @Test("maxWidth .infinity fills the proposal")
    func infiniteMaxFills() {
        #expect(width(maxWidth: .infinity, childWidth: 50, proposal: 300) == 300)
    }

    @Test("maxWidth grows to its cap, not past it")
    func finiteMaxCaps() {
        #expect(width(maxWidth: 200, childWidth: 50, proposal: 300) == 200)
    }

    @Test("a proposal smaller than maxWidth wins")
    func proposalBelowMax() {
        #expect(width(maxWidth: 200, childWidth: 50, proposal: 100) == 100)
    }

    @Test("an unspecified proposal falls back to content")
    func unspecifiedProposal() {
        #expect(width(maxWidth: 200, childWidth: 50, proposal: nil) == 50)
    }

    @Test("minWidth exceeds a smaller proposal")
    func minBeatsProposal() {
        #expect(width(minWidth: 100, childWidth: 20, proposal: 50) == 100)
    }

    @Test("minWidth wins when it conflicts with maxWidth")
    func minBeatsMax() {
        #expect(width(minWidth: 200, maxWidth: 100, childWidth: 50, proposal: 300) == 200)
    }

    @Test("a fixed frame ignores the proposal in both directions")
    func fixedIgnoresProposal() {
        let node = FLColor(.clear).frame(width: 44, height: 44)

        #expect(node.layout(in: FLContext(width: 300, height: 300)).size == CGSize(width: 44, height: 44))
        #expect(node.layout(in: FLContext.unspecified).size == CGSize(width: 44, height: 44))
        #expect(node.layout(in: FLContext(width: 10, height: 10)).size == CGSize(width: 44, height: 44))
    }

    @Test("maxHeight .infinity is a no-op against an unbounded height proposal")
    func infiniteMaxHeightWithoutBound() {
        let size = FLColor(.clear)
            .frame(width: 20, height: 20)
            .frame(maxHeight: .infinity)
            .layout(in: FLContext(width: 300))
            .size

        #expect(size.height == 20)
    }
}
