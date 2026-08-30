import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
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

public extension FLDecorated {
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

// MARK: - Node

public struct FLDecorated<Wrapped: FLNode>: FLNode {
    public typealias Layout = Wrapped.Layout
    public typealias View = FLDecoratedView<Wrapped>

    public let decoration: FLDecoration
    public let wrapped: Wrapped

    public func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context)
    }
}

// MARK: - FLLayoutEquatable

public extension FLDecorated {
    func isLayoutEquivalent(to other: FLDecorated<Wrapped>) -> Bool {
        wrapped.isLayoutEquivalent(to: other.wrapped)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        wrapped.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - View

public final class FLDecoratedView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLDecorated<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLDecorated<Wrapped>, layout: Wrapped.Layout, context: FLRenderContext) {
        let decoration = node.decoration

        backgroundColor = decoration.backgroundColor
        layer.cornerRadius = decoration.shape.cornerRadius(in: layout.size)
        layer.cornerCurve = decoration.cornerCurve.layerCornerCurve
        layer.maskedCorners = decoration.corners.cornerMask(in: context.environment.layoutDirection)
        layer.borderColor = decoration.borderColor.cgColor
        layer.borderWidth = decoration.borderWidth
        clipsToBounds = decoration.clipsToBounds
        drawsContent = decoration.backgroundColor.cgColor.alpha > 0 || decoration.borderWidth > 0

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout, context: context)
    }
}
