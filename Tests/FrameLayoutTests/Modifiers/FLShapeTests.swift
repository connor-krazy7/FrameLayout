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

    // No measured value carries the direction, so mirroring can only be read off the rendered layer.
    @Test("the corner mask is resolved at update from the render environment")
    @MainActor
    func maskResolvedAtUpdate() {
        #expect(
            Self.maskedCorners(of: Self.leadingRounded, in: .leftToRight)
                == [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        )
        #expect(
            Self.maskedCorners(of: Self.leadingRounded, in: .rightToLeft)
                == [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        )
    }

    @Test("the layout carries no direction, so both directions share it")
    func layoutIsDirectionIndependent() {
        let node = Self.leadingRounded

        #expect(
            node.layout(in: FLContext(width: 300, layoutDirection: .leftToRight))
                == node.layout(in: FLContext(width: 300, layoutDirection: .rightToLeft))
        )
    }

    private static var leadingRounded: some FLNode {
        FLColor(.red)
            .frame(width: 40, height: 40)
            .clipShape(.roundedRectangle(8), corners: .leading)
    }

    @MainActor
    private static func maskedCorners<Node: FLNode>(
        of node: Node,
        in direction: FLLayoutDirection
    ) -> CACornerMask {
        let layout = node.layout(in: FLContext(width: 300, layoutDirection: direction))
        let host = FLHostView<Node>()

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout, environment: FLEnvironment(layoutDirection: direction))
        host.layoutIfNeeded()

        return host.subviews[0].layer.maskedCorners
    }
}
