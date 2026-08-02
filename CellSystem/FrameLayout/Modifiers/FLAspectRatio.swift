import UIKit

enum FLAspectContentMode: Sendable, Hashable {
    /// The largest size with the ratio that fits inside the proposal.
    case fit
    /// The smallest size with the ratio that covers the proposal.
    case fill
}

struct FLAspectRatioLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout
    let wrappedFrame: CGRect
    let size: CGSize
}

struct FLAspectRatio<Wrapped: FLNode>: FLNode {
    typealias View = FLAspectRatioView<Wrapped>

    static var typeIdentifier: String { "aspectRatio(\(Wrapped.typeIdentifier))" }

    /// `nil` derives the ratio from the child's ideal size, which is what makes this behave as "fit
    /// the content's own shape".
    let ratio: CGFloat?
    let contentMode: FLAspectContentMode
    let alignment: FLAlignment
    let wrapped: Wrapped

    func layout(in context: FLContext) -> FLAspectRatioLayout<Wrapped.Layout> {
        let ideal = ratio == nil ? idealSize(in: context) : nil
        let derivedRatio = ideal.flatMap(Self.ratio(of:))
        let resolvedRatio = ratio.or(derivedRatio)
        let fallback = ideal.or(.zero)

        let size = resolvedRatio
            .map { resolvedSize(for: $0, in: context, ideal: ideal) }
            .or(fallback)

        let wrappedLayout = wrapped.layout(
            in: context.proposing(width: .exact(size.width), height: .exact(size.height))
        )

        return FLAspectRatioLayout(
            wrapped: wrappedLayout,
            wrappedFrame: CGRect(
                origin: alignment.origin(
                    childSize: wrappedLayout.size,
                    containerSize: size,
                    direction: context.layoutDirection
                ),
                size: wrappedLayout.size
            ),
            size: size
        )
    }

    /// Costs one extra measurement, and only when the ratio has to be derived.
    private func idealSize(in context: FLContext) -> CGSize {
        wrapped.layout(in: context.proposing(width: .unspecified, height: .unspecified)).size
    }

    private static func ratio(of size: CGSize) -> CGFloat? {
        guard size.width > 0, size.height > 0 else { return nil }
        return size.width / size.height
    }

    private func resolvedSize(for ratio: CGFloat, in context: FLContext, ideal: CGSize?) -> CGSize {
        guard ratio > 0 else { return .zero }
        guard context.width != .minimum, context.height != .minimum else { return .zero }

        switch (context.width.exactValue, context.height.exactValue) {
        case let (width?, height?):
            let heights = [width / ratio, height]
            let resolved = contentMode == .fit ? heights.min() : heights.max()

            return Self.size(ratio: ratio, height: resolved.or(height))

        case let (width?, nil):
            return CGSize(width: width, height: (width / ratio).rounded())

        case let (nil, height?):
            return Self.size(ratio: ratio, height: height)

        case (nil, nil):
            let isUnbounded = context.width == .maximum || context.height == .maximum

            return isUnbounded
                ? CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
                : ideal.or(.zero)
        }
    }

    private static func size(ratio: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: (height * ratio).rounded(), height: height.rounded())
    }
}

final class FLAspectRatioView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLAspectRatio<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLAspectRatio<Wrapped>, layout: FLAspectRatioLayout<Wrapped.Layout>, context: FLRenderContext) {
        wrappedView.flSetFrame(layout.wrappedFrame, in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

extension FLNodeProviding {
    func aspectRatio(
        _ ratio: CGFloat? = nil,
        contentMode: FLAspectContentMode = .fit,
        alignment: FLAlignment = .center
    ) -> FLAspectRatio<ProvidedNode> {
        FLAspectRatio(ratio: ratio, contentMode: contentMode, alignment: alignment, wrapped: flNode)
    }
}
