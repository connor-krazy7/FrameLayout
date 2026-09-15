import UIKit

public enum FLShape: Sendable, Hashable {
    case rectangle
    case roundedRectangle(CGFloat)
    case capsule
    case unevenRoundedRectangle(FLCornerRadii)

    // case path(any FLShapePath)
    //
    // Deliberately omitted. The first three cases resolve to `layer.cornerRadius`, which Core
    // Animation special-cases: no mask layer and no offscreen pass. It is also the only route that
    // supports `cornerCurve = .continuous` and `layer.maskedCorners`.
    //
    // An arbitrary path needs `CAShapeLayer` — either as a sublayer to paint a shaped fill, or as
    // `layer.mask` to clip children. The mask form adds an offscreen composite per view, which is
    // exactly the cost to avoid while scrolling, and it loses both continuous corners (there is no
    // public API for a squircle as a `CGPath`) and masked corners. The path would also have to be
    // rebuilt whenever the size changes, and cached by (shape, size) if it is expensive to build.
    //
    // It would additionally break `Hashable`/`Sendable` synthesis on `FLDecoration`, so it needs the
    // boxed-existential treatment used by `FLAnyLayout`: a captured comparator plus a hand-written
    // `hash(into:)`.
    //
    // `unevenRoundedRectangle` sits on the `CAShapeLayer` side of that line: it ignores
    // `cornerCurve`, and its path is rebuilt with the size.
    //
    // Worth adding when a design needs a shape that genuinely is not a rectangle with rounded
    // corners. Until then the closed enum is what keeps the renderer on the cheap path.

    public var roundsCorners: Bool {
        switch self {
        case .rectangle: false
        case let .roundedRectangle(radius): radius > 0
        case .capsule: true
        case let .unevenRoundedRectangle(radii): radii.roundsCorners
        }
    }

    /// The radius Core Animation can apply to every corner at once. `unevenRoundedRectangle` has
    /// none and answers 0, so it is not a square corner — it is drawn from `FLCornerRadii` instead.
    public func cornerRadius(in size: CGSize) -> CGFloat {
        switch self {
        case .rectangle: 0
        case let .roundedRectangle(radius): radius
        case .capsule: Swift.min(size.width, size.height) / 2
        case .unevenRoundedRectangle: 0
        }
    }
}
