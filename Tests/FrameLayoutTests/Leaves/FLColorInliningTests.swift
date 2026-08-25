import SwiftUI
import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Inlined colors")
struct FLColorInliningTests {
    private let context = FLContext(width: 100, height: 40)

    @Test("a UIColor produces the same node as wrapping it by hand")
    func uiColorMatchesTheWrapper() {
        #expect(UIColor.systemRed.flNode == FLColor(.systemRed))
        #expect(UIColor.systemRed.flNode.layout(in: context).size == FLColor(.systemRed).layout(in: context).size)
    }

    @Test("a SwiftUI Color converts to the same node twice over")
    func swiftUIColorIsStable() {
        #expect(Color.blue.flNode == Color.blue.flNode)
        #expect(Color.blue.flNode.layout(in: context).size == FLColor(.systemBlue).layout(in: context).size)
    }

    @Test("a bare color measures as a fill does")
    func bareColorMeasuresAsAFill() {
        let bare = FLVStack(spacing: 0) {
            UIColor.systemRed

            Color.blue
        }
        let wrapped = FLVStack(spacing: 0) {
            FLColor(.systemRed)

            FLColor(.systemBlue)
        }

        #expect(bare.layout(in: context).size == wrapped.layout(in: context).size)
    }

    @Test("a bare color renders through the same view as FLColor")
    func bareColorRenders() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        let node = UIColor.systemRed.tag("swatch").frame(width: 20, height: 10)
        let host = FLHostView<FLFrame<FLTagged<FLColor, String>>>()
        let layout = node.layout(in: context)

        window.addSubview(host)
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        let region = host.registry.view(withTag: "swatch")
        let colorView = host.registry.view(withTag: "swatch", as: FLColorView.self)

        #expect(region?.bounds.size == CGSize(width: 20, height: 10))
        #expect(colorView?.backgroundColor == .systemRed)
    }
}
