import UIKit

public struct FLCornerRadii: Sendable, Hashable {
    public var topLeading: CGFloat
    public var topTrailing: CGFloat
    public var bottomLeading: CGFloat
    public var bottomTrailing: CGFloat

    public init(
        topLeading: CGFloat = 0,
        topTrailing: CGFloat = 0,
        bottomLeading: CGFloat = 0,
        bottomTrailing: CGFloat = 0
    ) {
        self.topLeading = topLeading
        self.topTrailing = topTrailing
        self.bottomLeading = bottomLeading
        self.bottomTrailing = bottomTrailing
    }

    public var roundsCorners: Bool {
        topLeading > 0 || topTrailing > 0 || bottomLeading > 0 || bottomTrailing > 0
    }
}

extension FLCornerRadii {
    /// A corner absent from `corners` is flattened, whatever radius it carries here.
    func path(in rect: CGRect, corners: FLCorners, direction: FLLayoutDirection) -> UIBezierPath {
        let masked = masking(to: corners)
        let limit = min(rect.width, rect.height) / 2
        let isLeftToRight = direction == .leftToRight
        let topLeft = Self.clamped(isLeftToRight ? masked.topLeading : masked.topTrailing, to: limit)
        let topRight = Self.clamped(isLeftToRight ? masked.topTrailing : masked.topLeading, to: limit)
        let bottomRight = Self.clamped(isLeftToRight ? masked.bottomTrailing : masked.bottomLeading, to: limit)
        let bottomLeft = Self.clamped(isLeftToRight ? masked.bottomLeading : masked.bottomTrailing, to: limit)

        return Self.path(
            in: rect,
            topLeft: topLeft,
            topRight: topRight,
            bottomRight: bottomRight,
            bottomLeft: bottomLeft
        )
    }

    func masking(to corners: FLCorners) -> FLCornerRadii {
        FLCornerRadii(
            topLeading: corners.contains(.topLeading) ? topLeading : 0,
            topTrailing: corners.contains(.topTrailing) ? topTrailing : 0,
            bottomLeading: corners.contains(.bottomLeading) ? bottomLeading : 0,
            bottomTrailing: corners.contains(.bottomTrailing) ? bottomTrailing : 0
        )
    }

    func inset(by amount: CGFloat) -> FLCornerRadii {
        FLCornerRadii(
            topLeading: max(0, topLeading - amount),
            topTrailing: max(0, topTrailing - amount),
            bottomLeading: max(0, bottomLeading - amount),
            bottomTrailing: max(0, bottomTrailing - amount)
        )
    }
}

private extension FLCornerRadii {
    static func clamped(_ radius: CGFloat, to limit: CGFloat) -> CGFloat {
        radius < 0 ? 0 : min(radius, limit)
    }

    static func path(
        in rect: CGRect,
        topLeft: CGFloat,
        topRight: CGFloat,
        bottomRight: CGFloat,
        bottomLeft: CGFloat
    ) -> UIBezierPath {
        let path = UIBezierPath()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
            radius: topLeft,
            startAngle: .pi,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
            radius: topRight,
            startAngle: 1.5 * .pi,
            endAngle: 2 * .pi,
            clockwise: true
        )
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
            radius: bottomRight,
            startAngle: 0,
            endAngle: 0.5 * .pi,
            clockwise: true
        )
        path.addArc(
            withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: 0.5 * .pi,
            endAngle: .pi,
            clockwise: true
        )
        path.close()

        return path
    }
}
