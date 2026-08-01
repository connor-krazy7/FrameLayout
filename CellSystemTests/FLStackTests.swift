import Testing
import UIKit
@testable import CellSystem

@Suite("Stacks and layering")
struct FLStackTests {
    private func swatch(_ width: CGFloat, _ height: CGFloat) -> FLFrame<FLColor> {
        FLColor(.clear).frame(width: width, height: height)
    }

    @Test("VStack takes max width and summed height")
    func verticalSizing() {
        let node = FLVStack(spacing: 8) {
            swatch(100, 20)
            swatch(60, 30)
        }

        #expect(node.layout(in: FLContext(width: 300)).size == CGSize(width: 100, height: 58))
    }

    @Test("HStack packed takes summed width and max height")
    func horizontalPacked() {
        let node = FLHStack(spacing: 8) {
            swatch(50, 20)
            swatch(30, 40)
        }

        #expect(node.layout(in: FLContext(width: 300)).size == CGSize(width: 88, height: 40))
    }

    @Test("a spacer absorbs leftover width and pushes siblings apart")
    func horizontalSpacer() {
        let node = FLHStack(spacing: 0) {
            swatch(50, 20)
            FLSpacer()
            swatch(50, 20)
        }
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size.width == 300)
        #expect(layout.childFrames.first?.origin.x == 0)
        #expect(layout.childFrames[1] == CGRect(x: 50, y: 10, width: 200, height: 0))
        #expect(layout.childFrames.last?.origin.x == 250)
    }

    @Test("a spacer absorbs leftover height in a VStack")
    func verticalSpacer() {
        let node = FLVStack(spacing: 0) {
            swatch(40, 20)
            FLSpacer()
            swatch(40, 20)
        }
        let layout = node.layout(in: FLContext(width: 300, height: 200))

        #expect(layout.size.height == 200)
        #expect(layout.childFrames.first?.origin.y == 0)
        #expect(layout.childFrames.last?.origin.y == 180)
    }

    @Test("a spacer collapses to its minimum when the axis is unbounded")
    func spacerWithoutBound() {
        let node = FLVStack(spacing: 8) {
            swatch(40, 20)
            FLSpacer()
            swatch(40, 20)
        }
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size.height == 56)
        #expect(layout.childFrames.last?.origin.y == 36)
    }

    @Test("minLength is honoured even when there is no leftover")
    func spacerMinLength() {
        let node = FLHStack(spacing: 0) {
            swatch(50, 20)
            FLSpacer(minLength: 30)
            swatch(50, 20)
        }
        let layout = node.layout(in: FLContext(width: 100))

        #expect(layout.size.width == 130)
        #expect(layout.childFrames[1].width == 30)
    }

    @Test("several spacers split the leftover equally")
    func multipleSpacers() {
        let node = FLHStack(spacing: 0) {
            swatch(50, 20)
            FLSpacer()
            swatch(50, 20)
            FLSpacer()
            swatch(50, 20)
        }
        let layout = node.layout(in: FLContext(width: 350))

        #expect(layout.size.width == 350)
        #expect(layout.childFrames[1].width == 100)
        #expect(layout.childFrames[3].width == 100)
    }

    @Test("a spacer is inert in a ZStack, which has no axis to absorb along")
    func spacerInZStack() {
        let node = FLZStack {
            swatch(80, 60)
            FLSpacer()
        }

        #expect(node.layout(in: FLContext(width: 300, height: 300)).size == CGSize(width: 80, height: 60))
    }

    @Test("ZStack takes the per-axis union of its children")
    func zStackUnion() {
        let node = FLZStack(alignment: .bottomTrailing) {
            swatch(80, 20)
            swatch(20, 60)
        }
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 80, height: 60))
        #expect(layout.childFrames.first == CGRect(x: 0, y: 40, width: 80, height: 20))
        #expect(layout.childFrames.last == CGRect(x: 60, y: 0, width: 20, height: 60))
    }

    @Test("background sizes to the content and a greedy background cannot grow it")
    func backgroundSizesToContent() {
        let node = swatch(40, 40).background(
            FLColor(.red).frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        let layout = node.layout(in: FLContext(width: 300, height: 300))

        #expect(layout.size == CGSize(width: 40, height: 40))
        #expect(layout.secondary.size == CGSize(width: 40, height: 40))
    }

    @Test("overlay aligns within the content and leaves its size alone")
    func overlayAligns() {
        let node = swatch(80, 60).overlay(swatch(20, 20), alignment: .topTrailing)
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size == CGSize(width: 80, height: 60))
        #expect(layout.secondaryFrame == CGRect(x: 60, y: 0, width: 20, height: 20))
    }

    @Test("HStack distributes a bounded width across flexible children")
    func horizontalDistribution() {
        let node = FLHStack(spacing: 0) {
            FLColor(.red).frame(maxWidth: .infinity).frame(height: 20)
            FLColor(.blue).frame(maxWidth: .infinity).frame(height: 20)
        }
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size.width == 300)
        #expect(layout.childFrames.first?.width == 150)
        #expect(layout.childFrames.last?.width == 150)
    }

    @Test("a rigid child keeps its size while a flexible sibling absorbs the shortfall")
    func rigidBeatsFlexible() {
        let node = FLHStack(spacing: 0) {
            swatch(50, 20)
            FLColor(.blue).frame(maxWidth: .infinity).frame(height: 20)
        }
        let layout = node.layout(in: FLContext(width: 200))

        #expect(layout.size.width == 200)
        #expect(layout.childFrames.first?.width == 50)
        #expect(layout.childFrames.last?.width == 150)
    }

    @Test("children that already fit are never re-proposed")
    func noRedistributionWhenItFits() {
        let node = FLHStack(spacing: 8) {
            swatch(50, 20)
            swatch(30, 20)
        }
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size.width == 88)
        #expect(layout.childFrames.first?.width == 50)
        #expect(layout.childFrames.last?.width == 30)
    }

    @Test("a VStack distributes a bounded height the same way")
    func verticalDistribution() {
        let node = FLVStack(spacing: 0) {
            FLColor(.red).frame(maxHeight: .infinity).frame(width: 20)
            FLColor(.blue).frame(maxHeight: .infinity).frame(width: 20)
        }
        let layout = node.layout(in: FLContext(width: 100, height: 240))

        #expect(layout.size.height == 240)
        #expect(layout.childFrames.first?.height == 120)
        #expect(layout.childFrames.last?.height == 120)
    }

    @Test("an unbounded axis cannot distribute, so ideals stand")
    func unboundedAxisKeepsIdeals() {
        let node = FLVStack(spacing: 0) {
            FLColor(.red).frame(maxHeight: .infinity).frame(width: 20)
            swatch(20, 30)
        }
        let layout = node.layout(in: FLContext(width: 100))

        #expect(layout.childFrames.last?.height == 30)
    }
}
