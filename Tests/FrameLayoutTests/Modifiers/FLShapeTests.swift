import Testing
import UIKit
@testable import FrameLayout

@Suite("Shapes and corners")
struct FLShapeTests {
    @Test("capsule resolves from the laid-out size, not a hardcoded radius")
    func capsuleFollowsSize() {
        #expect(FLShape.capsule.cornerRadius(in: CGSize(width: 44, height: 44)) == 22)
        #expect(FLShape.capsule.cornerRadius(in: CGSize(width: 120, height: 40)) == 20)
        #expect(FLShape.capsule.cornerRadius(in: CGSize(width: 80, height: 80)) == 40)
    }

    @Test("rectangle and a zero rounded rectangle leave no clip behind")
    func noClipWhenSquare() {
        #expect(FLShape.rectangle.roundsCorners == false)
        #expect(FLShape.roundedRectangle(0).roundsCorners == false)
        #expect(FLShape.roundedRectangle(20).roundsCorners)
        #expect(FLShape.capsule.roundsCorners)
    }

    @Test("leading/trailing corners mirror under RTL, top/bottom do not")
    func cornerMaskMirrors() {
        #expect(FLCorners.leading.cornerMask(in: .leftToRight) == [.layerMinXMinYCorner, .layerMinXMaxYCorner])
        #expect(FLCorners.leading.cornerMask(in: .rightToLeft) == [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
        #expect(FLCorners.top.cornerMask(in: .leftToRight) == [.layerMinXMinYCorner, .layerMaxXMinYCorner])
        #expect(FLCorners.top.cornerMask(in: .rightToLeft) == [.layerMinXMinYCorner, .layerMaxXMinYCorner])
    }

    @Test("a grouped bubble drops its trailing corners on the correct side")
    func groupedBubbleCorners() {
        let grouped = FLCorners.all.subtracting(.trailing)

        #expect(grouped.cornerMask(in: .leftToRight) == [.layerMinXMinYCorner, .layerMinXMaxYCorner])
        #expect(grouped.cornerMask(in: .rightToLeft) == [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
    }

    @Test("the corner mask is resolved at layout time from the context")
    func maskResolvedInLayout() {
        let node = FLColor(.red)
            .frame(width: 40, height: 40)
            .clipShape(.roundedRectangle(8), corners: .leading)

        let ltr = node.layout(in: FLContext(width: 300, layoutDirection: .leftToRight))
        let rtl = node.layout(in: FLContext(width: 300, layoutDirection: .rightToLeft))

        #expect(ltr.cornerMask == [.layerMinXMinYCorner, .layerMinXMaxYCorner])
        #expect(rtl.cornerMask == [.layerMaxXMinYCorner, .layerMaxXMaxYCorner])
    }
}
