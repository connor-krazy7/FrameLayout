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

    func cornerRadii(_ radii: FLCornerRadii, corners: FLCorners = .all) -> FLDecorated<ProvidedNode> {
        clipShape(.unevenRoundedRectangle(radii), corners: corners)
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

    func cornerRadii(_ radii: FLCornerRadii, corners: FLCorners = .all) -> FLDecorated<Wrapped> {
        clipShape(.unevenRoundedRectangle(radii), corners: corners)
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
    private lazy var shapeLayer = CAShapeLayer()
    private lazy var borderLayer = CAShapeLayer()
    private var isShaped = false

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
        let direction = context.environment.layoutDirection

        layer.cornerCurve = decoration.cornerCurve.layerCornerCurve
        layer.maskedCorners = decoration.corners.cornerMask(in: direction)
        clipsToBounds = decoration.clipsToBounds
        drawsContent = decoration.backgroundColor.cgColor.alpha > 0 || decoration.borderWidth > 0

        switch decoration.shape {
        case .rectangle, .roundedRectangle, .capsule:
            applyCornerRadius(decoration, in: layout.size)
        case let .unevenRoundedRectangle(radii):
            applyOutline(radii, decoration: decoration, in: layout.size, direction: direction)
        }

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout, context: context)
    }
}

// MARK: - Helpers

private extension FLDecoratedView {
    func applyCornerRadius(_ decoration: FLDecoration, in size: CGSize) {
        removeOutlineLayers()

        backgroundColor = decoration.backgroundColor
        layer.cornerRadius = decoration.shape.cornerRadius(in: size)
        layer.borderColor = decoration.borderColor.cgColor
        layer.borderWidth = decoration.borderWidth
    }

    func applyOutline(
        _ radii: FLCornerRadii,
        decoration: FLDecoration,
        in size: CGSize,
        direction: FLLayoutDirection
    ) {
        let rect = CGRect(origin: .zero, size: size)

        layer.cornerRadius = 0
        layer.borderWidth = 0
        isShaped = true

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyFill(radii, decoration: decoration, in: rect, direction: direction)
        applyBorder(radii, decoration: decoration, in: rect, direction: direction)
        CATransaction.commit()
    }

    func applyFill(
        _ radii: FLCornerRadii,
        decoration: FLDecoration,
        in rect: CGRect,
        direction: FLLayoutDirection
    ) {
        let outline = radii.path(in: rect, corners: decoration.corners, direction: direction)

        layer.mask = nil
        shapeLayer.removeFromSuperlayer()
        shapeLayer.frame = rect
        shapeLayer.path = outline.cgPath

        if decoration.clipsToBounds {
            backgroundColor = decoration.backgroundColor
            shapeLayer.fillColor = UIColor.black.cgColor
            layer.mask = shapeLayer
        } else {
            backgroundColor = .clear
            shapeLayer.fillColor = decoration.backgroundColor.cgColor
            layer.insertSublayer(shapeLayer, at: 0)
        }
    }

    func applyBorder(
        _ radii: FLCornerRadii,
        decoration: FLDecoration,
        in rect: CGRect,
        direction: FLLayoutDirection
    ) {
        borderLayer.removeFromSuperlayer()

        guard decoration.borderWidth > 0 else { return }

        let inset = decoration.borderWidth / 2
        let strokeRect = rect.insetBy(dx: inset, dy: inset)
        let strokeRadii = radii.inset(by: inset)
        let stroke = strokeRadii.path(in: strokeRect, corners: decoration.corners, direction: direction)

        borderLayer.frame = rect
        borderLayer.path = stroke.cgPath
        borderLayer.fillColor = nil
        borderLayer.strokeColor = decoration.borderColor.cgColor
        borderLayer.lineWidth = decoration.borderWidth
        layer.addSublayer(borderLayer)
    }

    func removeOutlineLayers() {
        guard isShaped else { return }

        layer.mask = nil
        shapeLayer.removeFromSuperlayer()
        borderLayer.removeFromSuperlayer()
        isShaped = false
    }
}
