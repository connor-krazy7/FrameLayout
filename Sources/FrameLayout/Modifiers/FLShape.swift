import UIKit

public enum FLShape: Sendable, Hashable {
    case rectangle
    case roundedRectangle(CGFloat)
    case capsule

    // case path(any FLShapePath)
    //
    // Deliberately omitted. Every case above resolves to `layer.cornerRadius`, which Core Animation
    // special-cases: no mask layer and no offscreen pass. It is also the only route that supports
    // `cornerCurve = .continuous` and `layer.maskedCorners`.
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
    // Worth adding when a design needs a shape that genuinely is not a rounded rectangle. Until then
    // the closed enum is what lets the renderer stay on the cheap path.

    public var roundsCorners: Bool {
        switch self {
        case .rectangle: false
        case let .roundedRectangle(radius): radius > 0
        case .capsule: true
        }
    }

    public func cornerRadius(in size: CGSize) -> CGFloat {
        switch self {
        case .rectangle: 0
        case let .roundedRectangle(radius): radius
        case .capsule: Swift.min(size.width, size.height) / 2
        }
    }
}
