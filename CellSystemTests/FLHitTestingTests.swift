import Testing
import UIKit

@testable import CellSystem

/// Every `FLNode` makes a real `UIView`, so wrappers occupy the hit-test tree that SwiftUI's layout
/// containers never enter. These pin down that a wrapper passes a touch through unless something that
/// actually draws claims it.
@MainActor
@Suite("Hit testing")
struct FLHitTestingTests {
    private func hosted<Node: FLNode>(_ node: Node, width: CGFloat = 100, height: CGFloat = 100) -> FLHostView<Node> {
        let host = FLHostView<Node>()
        let layout = node.layout(in: FLContext(width: width, height: height))

        host.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("padding does not swallow a touch that lands on it")
    func paddingPassesThrough() {
        let host = hosted(FLColor(.red).frame(width: 20, height: 20).padding(30))

        let onPadding = host.hitTest(CGPoint(x: 5, y: 5), with: nil)
        let onContent = host.hitTest(CGPoint(x: 40, y: 40), with: nil)

        #expect(onPadding === host)
        #expect(onContent is FLColorView)
    }

    /// The case that rules out checking subview frames directly. Every level here is a wrapper, so a
    /// frame-containment test at each level would hand the touch to the next wrapper down and the
    /// stack would still swallow it. Returning `nil` when nothing claimed the point is what lets
    /// UIKit keep looking at the *siblings* instead.
    @Test("a tower of wrappers passes a touch through all of them")
    func nestedWrappersPassThrough() {
        let node = FLVStack(alignment: .leading) {
            FLColor(.red)
                .frame(width: 10, height: 10)
                .padding(5)
                .opacity(0.9)
        }
        let host = hosted(node)

        let insideWrappersOnly = host.hitTest(CGPoint(x: 2, y: 2), with: nil)
        let onTheColor = host.hitTest(CGPoint(x: 10, y: 10), with: nil)

        #expect(insideWrappersOnly === host)
        #expect(onTheColor is FLColorView)
    }

    @Test("an overlay wrapper does not block content beneath it")
    func overlayDoesNotBlockContent() {
        let node = FLColor(.red)
            .frame(width: 100, height: 100)
            .overlay(FLColor(.clear).frame(width: 100, height: 100).padding(0))
        let host = hosted(node)

        let hit = host.hitTest(CGPoint(x: 50, y: 50), with: nil)

        #expect(hit is FLColorView)
    }

    @Test("a filled background claims the touch, an unfilled decoration does not")
    func fillDecidesWhetherADecorationIsTouchable() {
        let filled = hosted(FLSpacer().frame(width: 100, height: 100).background(.systemBlue))
        let clipped = hosted(FLSpacer().frame(width: 100, height: 100).clipped())

        let onFilled = filled.hitTest(CGPoint(x: 50, y: 50), with: nil)
        let onClipped = clipped.hitTest(CGPoint(x: 50, y: 50), with: nil)

        #expect(onFilled is FLDecoratedView<FLFrame<FLSpacer>>)
        #expect(onClipped === clipped)
    }

    @Test("a content leaf keeps the touch")
    func leavesAreTouchable() {
        let host = hosted(FLColor(.red).frame(width: 100, height: 100))

        #expect(host.hitTest(CGPoint(x: 50, y: 50), with: nil) is FLColorView)
    }

    @Test("allowsHitTesting(false) takes the whole subtree out of the path")
    func hitTestingCanBeDisabled() {
        let host = hosted(
            FLColor(.red).frame(width: 100, height: 100).allowsHitTesting(false)
        )

        #expect(host.hitTest(CGPoint(x: 50, y: 50), with: nil) === host)
    }

    @Test("opacity alone leaves the subtree touchable")
    func opacityKeepsInteraction() {
        let host = hosted(FLColor(.red).frame(width: 100, height: 100).opacity(0.5))

        #expect(host.hitTest(CGPoint(x: 50, y: 50), with: nil) is FLColorView)
    }

    @Test("a touch outside the content finds nothing in it")
    func outsideContentMisses() {
        let host = hosted(FLColor(.red).frame(width: 20, height: 20), width: 100, height: 100)

        #expect(host.hitTest(CGPoint(x: 90, y: 90), with: nil) === host)
    }
}
