import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Modifiers on composites")
struct FLCompositeModifierTests {
    private let context = FLContext(width: 300)

    @Test("a composite takes modifiers without being converted first")
    func compositeTakesModifiers() {
        let padded = NestedPlain().padding(10)
        let node = NestedPlain().node.padding(10)

        #expect(padded.layout(in: context).size == node.layout(in: context).size)
    }

    @Test("modifiers chain on a composite the same way they do on a node")
    func modifiersChain() {
        let chained = NestedPlain()
            .padding(8)
            .background(.systemRed, in: .roundedRectangle(4))
            .opacity(0.5)
            .frame(width: 100, height: 60)

        #expect(chained.layout(in: context).size == CGSize(width: 100, height: 60))
    }

    @Test("a modified composite is still a node the builders accept")
    func modifiedCompositeComposes() {
        let stack = FLVStack(spacing: 4) {
            NestedPlain().padding(6)
            NestedPlain()
        }

        #expect(stack.layout(in: context).size.height == CGFloat(20 + 12 + 4 + 20))
    }

    @Test("tagging a composite registers the view it produced")
    func taggingAComposite() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let host = FLHostView<FLTagged<FLComposed<NestedPlain>, String>>()
        let node = NestedPlain().tag("plain")
        let layout = node.layout(in: context)

        window.addSubview(host)
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        #expect(host.registry.containsView(withTag: "plain"))
    }

    @Test("modifying a composite does not change what it measures")
    func modifyingIsLayoutNeutralWhereItShouldBe() {
        let bare = NestedPlain().node.layout(in: context).size
        let tagged = NestedPlain().tag("plain").layout(in: context).size
        let faded = NestedPlain().opacity(0.3).layout(in: context).size

        #expect(bare == tagged)
        #expect(bare == faded)
    }
}
