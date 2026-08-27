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

    // Both orderings measure 60×60 with the content inset by 10, so a layout assertion cannot tell them
    // apart. The difference is how much of that box the background covers, which the decoration applies
    // at update — hence the view-level assertions.
    @Test("padding then background fills the whole padded box, background then padding does not")
    @MainActor
    func decorationExtentFollowsOrdering() {
        let inside = FLColor(.red).frame(width: 40, height: 40).padding(10).background(.systemBlue)
        let outside = FLColor(.red).frame(width: 40, height: 40).background(.systemBlue).padding(10)

        #expect(inside.layout(in: FLContext(width: 300)).size == CGSize(width: 60, height: 60))
        #expect(outside.layout(in: FLContext(width: 300)).size == CGSize(width: 60, height: 60))

        // Padding then background: the decorated view *is* the content view, so it covers the box.
        #expect(Self.hosted(inside).subviews[0].frame == CGRect(x: 0, y: 0, width: 60, height: 60))

        // Background then padding: the decorated view sits inside the padded view, inset by 10.
        #expect(
            Self.hosted(outside).subviews[0].subviews[0].frame
                == CGRect(x: 10, y: 10, width: 40, height: 40)
        )
    }

    @MainActor
    private static func hosted<Node: FLNode>(_ node: Node) -> FLHostView<Node> {
        let layout = node.layout(in: FLContext(width: 300))
        let host = FLHostView<Node>()

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
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
