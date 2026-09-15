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
        #expect(FLShape.unevenRoundedRectangle(FLCornerRadii()).roundsCorners == false)
        #expect(FLShape.unevenRoundedRectangle(Self.tailRadii).roundsCorners)
    }

    @Test("an uneven shape has no single radius Core Animation could apply")
    func unevenShapeHasNoUniformRadius() {
        let shape = FLShape.unevenRoundedRectangle(Self.tailRadii)

        #expect(shape.cornerRadius(in: CGSize(width: 100, height: 60)) == 0)
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

    @Test("an uneven shape leaves the cornerRadius route and clips with a mask")
    @MainActor
    func unevenShapeClipsWithAMask() {
        let decorated = Self.hosted(Self.swatch(Self.tail), in: .leftToRight).subviews[0]

        #expect(decorated.layer.mask is CAShapeLayer)
        #expect(decorated.layer.cornerRadius == 0)
    }

    @Test("an unclipped uneven shape fills with a sublayer, so content can still overflow")
    @MainActor
    func unclippedUnevenShapeFillsWithASublayer() {
        let decorated = Self.hosted(Self.unclippedSwatch(Self.tail), in: .leftToRight).subviews[0]
        let fill = decorated.layer.sublayers?.first as? CAShapeLayer

        #expect(decorated.layer.mask == nil)
        #expect(fill?.fillColor == UIColor.red.cgColor)
        #expect(decorated.backgroundColor == UIColor.clear)
    }

    @Test("an uneven border is stroked, because layer.borderWidth would follow the bounds")
    @MainActor
    func unevenBorderIsStroked() {
        let decorated = Self.hosted(Self.borderedSwatch(Self.tail), in: .leftToRight).subviews[0]
        let strokes = decorated.layer.sublayers?.compactMap { $0 as? CAShapeLayer }

        #expect(decorated.layer.borderWidth == 0)
        #expect(strokes?.count == 1)
        #expect(strokes?.first?.lineWidth == 2)
        #expect(strokes?.first?.strokeColor == UIColor.blue.cgColor)
    }

    @Test("a reused view drops its outline layers when the shape becomes uniform again")
    @MainActor
    func reuseDropsTheOutlineLayers() {
        let host = Self.hosted(Self.swatch(Self.tail), in: .leftToRight)

        #expect(host.subviews[0].layer.mask != nil)

        Self.apply(Self.swatch(.roundedRectangle(8)), to: host, in: .leftToRight)

        #expect(host.subviews[0].layer.mask == nil)
        #expect(host.subviews[0].layer.cornerRadius == 8)
    }

    @Test("a clip collapses only where the static type is still FLDecorated")
    func clipCollapsesOnlyOnAConcreteDecoration() {
        let concrete = FLColor(.red).frame(width: 100, height: 60).clipShape(.roundedRectangle(8))
        let collapsed = concrete.clipped(false)
        let opaque = Self.swatch(.roundedRectangle(8)).clipped(false)
        let composite = FixtureAvatar(initials: "AB", id: "a").clipped(false)

        #expect(collapsed.decoration.shape == .roundedRectangle(8))
        #expect(collapsed.decoration.clipsToBounds == false)
        #expect(opaque.decoration.shape == .rectangle)
        #expect(composite.decoration.shape == .rectangle)
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
        hosted(node, in: direction).subviews[0].layer.maskedCorners
    }

    @MainActor
    private static func hosted<Node: FLNode>(
        _ node: Node,
        in direction: FLLayoutDirection
    ) -> FLHostView<Node> {
        let host = FLHostView<Node>()

        apply(node, to: host, in: direction)

        return host
    }

    @MainActor
    private static func apply<Node: FLNode>(
        _ node: Node,
        to host: FLHostView<Node>,
        in direction: FLLayoutDirection
    ) {
        let layout = node.layout(in: FLContext(width: 300, layoutDirection: direction))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout, environment: FLEnvironment(layoutDirection: direction))
        host.layoutIfNeeded()
    }

    private static let tailRadii = FLCornerRadii(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 20,
        bottomTrailing: 4
    )

    private static let tail = FLShape.unevenRoundedRectangle(tailRadii)

    private static func swatch(_ shape: FLShape) -> some FLNode {
        FLColor(.red).frame(width: 100, height: 60).clipShape(shape)
    }

    private static func unclippedSwatch(_ shape: FLShape) -> some FLNode {
        FLColor(.red).frame(width: 100, height: 60).background(.red, in: shape).clipped(false)
    }

    private static func borderedSwatch(_ shape: FLShape) -> some FLNode {
        FLColor(.red).frame(width: 100, height: 60).border(.blue, width: 2).clipShape(shape)
    }
}
