import Testing
import UIKit
@testable import FrameLayout

@Suite("Alignment, including overflow")
struct FLAlignmentTests {
    // Regression: slack was clamped to >= 0, which pinned an oversized child to leading
    // instead of centring it. Every child in a stack came out offset by half the overflow.
    @Test("an oversized child centres and overflows symmetrically")
    func oversizedChildCentres() {
        #expect(FLHorizontalAlignment.center.originX(childWidth: 300, containerWidth: 200, direction: .leftToRight) == -50)
        #expect(FLVerticalAlignment.center.originY(childHeight: 300, containerHeight: 200) == -50)
    }

    @Test("an oversized leading child overflows trailing only")
    func oversizedLeading() {
        #expect(FLHorizontalAlignment.leading.originX(childWidth: 300, containerWidth: 200, direction: .leftToRight) == 0)
        #expect(FLHorizontalAlignment.leading.originX(childWidth: 300, containerWidth: 200, direction: .rightToLeft) == -100)
    }

    @Test("an oversized trailing child overflows leading only")
    func oversizedTrailing() {
        #expect(FLHorizontalAlignment.trailing.originX(childWidth: 300, containerWidth: 200, direction: .leftToRight) == -100)
        #expect(FLHorizontalAlignment.trailing.originX(childWidth: 300, containerWidth: 200, direction: .rightToLeft) == 0)
    }

    @Test("a fitting child is unaffected")
    func fittingChild() {
        #expect(FLHorizontalAlignment.center.originX(childWidth: 100, containerWidth: 300, direction: .leftToRight) == 100)
        #expect(FLHorizontalAlignment.leading.originX(childWidth: 100, containerWidth: 300, direction: .leftToRight) == 0)
        #expect(FLHorizontalAlignment.trailing.originX(childWidth: 100, containerWidth: 300, direction: .leftToRight) == 200)
        #expect(FLHorizontalAlignment.leading.originX(childWidth: 100, containerWidth: 300, direction: .rightToLeft) == 200)
    }

    @Test("padding mirrors leading/trailing under RTL")
    func paddingMirrors() {
        let insets = FLEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 40)

        #expect(insets.left(in: .leftToRight) == 20)
        #expect(insets.left(in: .rightToLeft) == 40)
    }
}
