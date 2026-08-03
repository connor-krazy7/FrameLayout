import UIKit

enum FLCornerCurve: Sendable, Hashable {
    case circular
    case continuous

    var layerCornerCurve: CALayerCornerCurve {
        switch self {
        case .circular: .circular
        case .continuous: .continuous
        }
    }
}

enum FLShape: Sendable, Hashable {
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

    var roundsCorners: Bool {
        switch self {
        case .rectangle: false
        case let .roundedRectangle(radius): radius > 0
        case .capsule: true
        }
    }

    func cornerRadius(in size: CGSize) -> CGFloat {
        switch self {
        case .rectangle: 0
        case let .roundedRectangle(radius): radius
        case .capsule: Swift.min(size.width, size.height) / 2
        }
    }
}

struct FLDecoration: Sendable, Hashable, WithCustomisable {
    var backgroundColor: UIColor = .clear
    var shape: FLShape = .rectangle
    var corners: FLCorners = .all
    var cornerCurve: FLCornerCurve = .circular
    var borderColor: UIColor = .clear
    var borderWidth: CGFloat = 0
    var clipsToBounds: Bool = false
}

struct FLDecoratedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout
    let cornerMask: CACornerMask

    var size: CGSize { wrapped.size }
}

struct FLDecorated<Wrapped: FLNode>: FLNode {
    typealias View = FLDecoratedView<Wrapped>

    static var typeIdentifier: String { "decorated(\(Wrapped.typeIdentifier))" }

    let decoration: FLDecoration
    let wrapped: Wrapped

    func layout(in context: FLContext) -> FLDecoratedLayout<Wrapped.Layout> {
        FLDecoratedLayout(
            wrapped: wrapped.layout(in: context),
            cornerMask: decoration.corners.cornerMask(in: context.layoutDirection)
        )
    }
}

final class FLDecoratedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLDecorated<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLDecorated<Wrapped>, layout: FLDecoratedLayout<Wrapped.Layout>, context: FLRenderContext) {
        let decoration = node.decoration

        backgroundColor = decoration.backgroundColor
        layer.cornerRadius = decoration.shape.cornerRadius(in: layout.size)
        layer.cornerCurve = decoration.cornerCurve.layerCornerCurve
        layer.maskedCorners = layout.cornerMask
        layer.borderColor = decoration.borderColor.cgColor
        layer.borderWidth = decoration.borderWidth
        clipsToBounds = decoration.clipsToBounds
        drawsContent = decoration.backgroundColor.cgColor.alpha > 0 || decoration.borderWidth > 0

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.wrapped.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

extension FLNodeProviding {
    func decoration(_ transform: (inout FLDecoration) -> Void) -> FLDecorated<ProvidedNode> {
        FLDecorated(decoration: FLDecoration().with(transform), wrapped: flNode)
    }

    func background(_ color: UIColor) -> FLDecorated<ProvidedNode> {
        decoration { $0.backgroundColor = color }
    }

    func background(
        _ color: UIColor,
        in shape: FLShape,
        corners: FLCorners = .all,
        curve: FLCornerCurve = .circular
    ) -> FLDecorated<ProvidedNode> {
        decoration {
            $0.backgroundColor = color
            $0.shape = shape
            $0.corners = corners
            $0.cornerCurve = curve
            $0.clipsToBounds = shape.roundsCorners
        }
    }

    func clipShape(
        _ shape: FLShape,
        corners: FLCorners = .all,
        curve: FLCornerCurve = .circular
    ) -> FLDecorated<ProvidedNode> {
        decoration {
            $0.shape = shape
            $0.corners = corners
            $0.cornerCurve = curve
            $0.clipsToBounds = shape.roundsCorners
        }
    }

    func cornerRadius(
        _ radius: CGFloat,
        corners: FLCorners = .all,
        curve: FLCornerCurve = .circular
    ) -> FLDecorated<ProvidedNode> {
        clipShape(.roundedRectangle(radius), corners: corners, curve: curve)
    }

    func border(_ color: UIColor, width: CGFloat = 1) -> FLDecorated<ProvidedNode> {
        decoration {
            $0.borderColor = color
            $0.borderWidth = width
        }
    }

    func clipped(_ isClipped: Bool = true) -> FLDecorated<ProvidedNode> {
        decoration { $0.clipsToBounds = isClipped }
    }
}

extension FLDecorated {
    func clipShape(
        _ shape: FLShape,
        corners: FLCorners = .all,
        curve: FLCornerCurve = .circular
    ) -> FLDecorated<Wrapped> {
        FLDecorated(
            decoration: decoration.with {
                $0.shape = shape
                $0.corners = corners
                $0.cornerCurve = curve
                $0.clipsToBounds = shape.roundsCorners
            },
            wrapped: wrapped
        )
    }

    func cornerRadius(
        _ radius: CGFloat,
        corners: FLCorners = .all,
        curve: FLCornerCurve = .circular
    ) -> FLDecorated<Wrapped> {
        clipShape(.roundedRectangle(radius), corners: corners, curve: curve)
    }

    func clipped(_ isClipped: Bool = true) -> FLDecorated<Wrapped> {
        FLDecorated(decoration: decoration.with { $0.clipsToBounds = isClipped }, wrapped: wrapped)
    }
}
