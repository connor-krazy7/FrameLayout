import Testing
import UIKit
@testable import FrameLayout

/// Covers the outline `FLCornerRadii` describes: which physical corner each radius reaches, how a
/// radius is bounded by the box, and how `FLCorners` flattens one.
///
/// It asserts geometry only. That the outline is applied as a mask when the decoration clips and as
/// a fill sublayer when it does not is `FLShapeTests`, which needs a rendered layer to see it.
@Suite("Uneven corner radii")
struct FLCornerRadiiTests {
    @Test("a radius rounds only its own corner")
    func eachCornerIsIndependent() {
        let path = Self.bubble.path(in: Self.box, corners: .all, direction: .leftToRight)

        #expect(path.contains(CGPoint(x: 2, y: 2)) == false)
        #expect(path.contains(CGPoint(x: 98, y: 58)))
    }

    @Test("the outline is tangent to the box on every edge")
    func outlineFillsTheBox() {
        let path = Self.bubble.path(in: Self.box, corners: .all, direction: .leftToRight)

        #expect(path.bounds == Self.box)
    }

    @Test("leading and trailing resolve to opposite sides under RTL")
    func radiiMirror() {
        let radii = FLCornerRadii(topLeading: 20)
        let leftToRight = radii.path(in: Self.box, corners: .all, direction: .leftToRight)
        let rightToLeft = radii.path(in: Self.box, corners: .all, direction: .rightToLeft)

        #expect(leftToRight.contains(CGPoint(x: 2, y: 2)) == false)
        #expect(leftToRight.contains(CGPoint(x: 98, y: 2)))
        #expect(rightToLeft.contains(CGPoint(x: 2, y: 2)))
        #expect(rightToLeft.contains(CGPoint(x: 98, y: 2)) == false)
    }

    @Test("a corner absent from FLCorners is flattened, whatever its radius")
    func cornersFlattenARadius() {
        let radii = FLCornerRadii(
            topLeading: 20,
            topTrailing: 20,
            bottomLeading: 20,
            bottomTrailing: 20
        )
        let path = radii.path(in: Self.box, corners: .top, direction: .leftToRight)

        #expect(path.contains(CGPoint(x: 2, y: 2)) == false)
        #expect(path.contains(CGPoint(x: 2, y: 58)))
        #expect(path.contains(CGPoint(x: 98, y: 58)))
    }

    @Test("a radius larger than the box is bounded by half its shorter side")
    func radiiAreBounded() {
        let radii = FLCornerRadii(
            topLeading: 999,
            topTrailing: 999,
            bottomLeading: 999,
            bottomTrailing: 999
        )
        let path = radii.path(in: Self.box, corners: .all, direction: .leftToRight)

        #expect(path.bounds == Self.box)
        #expect(path.contains(CGPoint(x: 1, y: 30)))
        #expect(path.contains(CGPoint(x: 1, y: 1)) == false)
    }

    @Test("a negative radius is a square corner, not an inverted arc")
    func negativeRadiiAreSquare() {
        let radii = FLCornerRadii(topLeading: -20)
        let path = radii.path(in: Self.box, corners: .all, direction: .leftToRight)

        #expect(path.bounds == Self.box)
        #expect(path.contains(CGPoint(x: 1, y: 1)))
    }

    @Test("insetting floors at zero rather than going negative")
    func insetFloorsAtZero() {
        let inset = Self.bubble.inset(by: 6)

        #expect(inset.topLeading == 14)
        #expect(inset.bottomTrailing == 0)
    }

    private static let box = CGRect(x: 0, y: 0, width: 100, height: 60)

    private static let bubble = FLCornerRadii(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 20,
        bottomTrailing: 4
    )
}
