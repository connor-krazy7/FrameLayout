import SwiftUI
import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Layering with builders")
struct FLLayeredBuilderTests {
    private let context = FLContext(width: 200)

    @Test("a builder background matches passing the node directly")
    func builderBackgroundMatchesTheDirectForm() {
        let direct = FLText("x").padding(8).background(FLColor(.systemMint))
        let built = FLText("x").padding(8).background { UIColor.systemMint }

        #expect(direct.layout(in: context).size == built.layout(in: context).size)
    }

    @Test("a builder overlay honours its alignment")
    func builderOverlayHonoursAlignment() {
        let node = FLColor(.systemGray5)
            .frame(width: 40, height: 40)
            .overlay(alignment: .topTrailing) {
                Color.red.frame(width: 6, height: 6)
            }
        let layout = node.layout(in: context)

        #expect(layout.size == CGSize(width: 40, height: 40))
        #expect(layout.secondaryFrame.maxX == 40)
        #expect(layout.secondaryFrame.minY == 0)
    }

    @Test("a builder closure takes a whole subtree, not just one node")
    func builderTakesASubtree() {
        let node = FLText("x")
            .padding(8)
            .background(alignment: .bottom) {
                FLVStack(spacing: 0) {
                    UIColor.systemGray5

                    UIColor.systemGray6
                }
            }

        #expect(node.layout(in: context).size == FLText("x").padding(8).layout(in: context).size)
    }
}
