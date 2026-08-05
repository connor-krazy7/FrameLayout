import Testing
import UIKit
@testable import FrameLayout

@Suite("Modifier composition")
struct FLCompositionTests {
    @Test("alternating padding and background grows 40 -> 60 -> 80")
    func nestedRings() {
        let node = FLColor(.red)
            .frame(width: 40, height: 40)
            .padding(10)
            .background(.systemBlue)
            .padding(10)
            .background(.systemYellow)

        #expect(node.layout(in: FLContext(width: 300)).size == CGSize(width: 80, height: 80))
    }

    @Test("adjacent paddings merge into one node")
    func paddingMerges() {
        let node = FLColor(.red).frame(width: 40, height: 40).padding(8).padding(4)

        #expect(node.insets == FLEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        #expect(node.layout(in: FLContext(width: 300)).size == CGSize(width: 64, height: 64))
    }

    @Test("background then padding leaves the margin transparent")
    func backgroundThenPadding() {
        let node = FLColor(.red).frame(width: 40, height: 40).background(.systemBlue).padding(10)
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 60, height: 60))
        #expect(layout.wrappedFrame == CGRect(x: 10, y: 10, width: 40, height: 40))
    }

    @Test("padding then background fills the whole padded box")
    func paddingThenBackground() {
        let node = FLColor(.red).frame(width: 40, height: 40).padding(10).background(.systemBlue)
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 60, height: 60))
        #expect(layout.wrapped.size == CGSize(width: 60, height: 60))
    }

    @Test("decoration does not change size")
    func decorationIsSizeNeutral() {
        let bare = FLColor(.red).frame(width: 40, height: 40)
        let decorated = bare.background(.systemBlue, in: .capsule).border(.black, width: 2)

        #expect(decorated.layout(in: FLContext(width: 300)).size == bare.layout(in: FLContext(width: 300)).size)
    }

    @Test("clipped(false) leaves clipping off")
    func clippedTakesABool() {
        #expect(FLColor(.red).clipped().decoration.clipsToBounds)
        #expect(FLColor(.red).clipped(false).decoration.clipsToBounds == false)
    }
}
