import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Frame-driven representables")
struct FLFrameBasedRepresentableTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))

    @Test("the size comes from the data, not from the view")
    func sizeComesFromData() {
        let strip = FixtureBadgeStrip(count: 4)
        let size = strip.flNode.layout(in: FLContext(width: 320)).size

        #expect(size == CGSize(width: strip.naturalWidth, height: 20))
        #expect(FixtureBadgeStrip(count: 1).flNode.layout(in: FLContext(width: 320)).size.width == 20)
    }

    @Test("a tighter proposal clamps the strip rather than letting it overflow")
    func tighterProposalClamps() {
        let size = FixtureBadgeStrip(count: 8).flNode.layout(in: FLContext(width: 40)).size

        #expect(size.width == 40)
    }

    @Test("the subviews are laid out inside the reserved box")
    func subviewsFillTheReservedBox() {
        let strip = FixtureBadgeStrip(count: 3)
        let node = strip.flNode.tag("strip")
        let host = FLHostView<FLTagged<FLRepresentableNode<FixtureBadgeStrip>, String>>()
        let layout = node.layout(in: FLContext(width: 320))

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        let injected = host.registry.view(withTag: "strip", as: FixtureBadgeStripView.self)

        #expect(injected?.bounds.size == layout.size)
        #expect(injected?.subviews.count == 3)
        #expect(injected?.subviews.allSatisfy { $0.frame.maxX <= layout.size.width + 0.5 } == true)
    }
}
