import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
    func aspectRatio(
        _ ratio: CGFloat? = nil,
        contentMode: FLAspectContentMode = .fit,
        alignment: FLAlignment = .center
    ) -> FLAspectRatio<ProvidedNode> {
        FLAspectRatio(ratio: ratio, contentMode: contentMode, alignment: alignment, wrapped: flNode)
    }
}

// A cap on a ratio-driven node bounds both axes, because the ratio ties them together: staying inside a
// height limit already bounds the width, and vice versa. Each overload derives the limit it was not given
// — `maxHeight * ratio` is the width at which the height reaches its cap — so all three reserve the largest
// ratio-shaped box inside the limits, and `.fill`, which answers larger than any proposal, cannot leave a
// box that is the wrong shape. That is a stronger promise than the bare `frame(maxWidth:)` / `frame(maxHeight:)`
// spellings make; reach for those when the SwiftUI behaviour is what is wanted.
public extension FLNodeProviding {
    func aspectRatio(
        _ ratio: CGFloat,
        contentMode: FLAspectContentMode = .fit,
        maxWidth: CGFloat,
        alignment: FLAlignment = .center
    ) -> FLFrame<FLAspectRatio<ProvidedNode>> {
        aspectRatio(
            ratio,
            contentMode: contentMode,
            boundedBy: CGSize(width: maxWidth, height: maxWidth / ratio),
            alignment: alignment
        )
    }

    func aspectRatio(
        _ ratio: CGFloat,
        contentMode: FLAspectContentMode = .fit,
        maxHeight: CGFloat,
        alignment: FLAlignment = .center
    ) -> FLFrame<FLAspectRatio<ProvidedNode>> {
        aspectRatio(
            ratio,
            contentMode: contentMode,
            boundedBy: CGSize(width: maxHeight * ratio, height: maxHeight),
            alignment: alignment
        )
    }

    /// The largest box with this ratio that stays inside `limit` on both axes. Either dimension may be the
    /// binding one, so the tighter of `limit.width` and `limit.height * ratio` decides.
    func aspectRatio(
        _ ratio: CGFloat,
        contentMode: FLAspectContentMode = .fit,
        boundedBy limit: CGSize,
        alignment: FLAlignment = .center
    ) -> FLFrame<FLAspectRatio<ProvidedNode>> {
        aspectRatio(ratio, contentMode: contentMode, alignment: alignment)
            .frame(
                maxWidth: min(limit.width, limit.height * ratio),
                maxHeight: min(limit.height, limit.width / ratio)
            )
    }
}

// MARK: - Node

public struct FLAspectRatio<Wrapped: FLNode>: FLNode {
    public typealias View = FLAspectRatioView<Wrapped>

    /// `nil` derives the ratio from the child's ideal size, which is what makes this behave as "fit
    /// the content's own shape".
    public let ratio: CGFloat?
    public let contentMode: FLAspectContentMode
    public let alignment: FLAlignment
    public let wrapped: Wrapped

    public func layout(in context: FLContext) -> FLAspectRatioLayout<Wrapped.Layout> {
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

// MARK: - Layout

public struct FLAspectRatioLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout
    public let wrappedFrame: CGRect
    public let size: CGSize
}

// MARK: - View

public final class FLAspectRatioView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLAspectRatio<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLAspectRatio<Wrapped>, layout: FLAspectRatioLayout<Wrapped.Layout>, context: FLRenderContext) {
        wrappedView.flSetFrame(layout.wrappedFrame, in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}
