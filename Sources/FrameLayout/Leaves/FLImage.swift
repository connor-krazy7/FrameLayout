import UIKit

// MARK: - Node

/// Reports the image's own point size, like a non-resizable SwiftUI `Image`. Call `resizable()` to
/// let it accept a proposal instead; every other sizing behaviour comes from modifiers.
public struct FLImage: FLNode {
    public typealias View = FLImageView

    public let image: UIImage?
    public let contentMode: UIView.ContentMode
    public let overrides: FLEnvironmentOverrides
    public let isResizable: Bool

    public init(_ image: UIImage?) {
        self.init(image, contentMode: .scaleAspectFit, overrides: FLEnvironmentOverrides(), isResizable: false)
    }

    private init(
        _ image: UIImage?,
        contentMode: UIView.ContentMode,
        overrides: FLEnvironmentOverrides,
        isResizable: Bool
    ) {
        self.image = image
        self.contentMode = contentMode
        self.overrides = overrides
        self.isResizable = isResizable
    }

    public func layout(in context: FLContext) -> FLImageLayout {
        guard isResizable else { return FLImageLayout(size: intrinsicSize) }

        return FLImageLayout(
            size: CGSize(
                width: context.width.resolved(ideal: intrinsicSize.width),
                height: context.height.resolved(ideal: intrinsicSize.height)
            )
        )
    }

    private var intrinsicSize: CGSize {
        (image?.size).or(.zero)
    }
}

// MARK: - Modifiers

public extension FLImage {
    /// Only the image knows it can be resampled, so willingness to take a proposal has to live here
    /// rather than in a modifier.
    func resizable() -> FLImage {
        FLImage(image, contentMode: contentMode, overrides: overrides, isResizable: true)
    }

    func contentMode(_ contentMode: UIView.ContentMode) -> FLImage {
        FLImage(image, contentMode: contentMode, overrides: overrides, isResizable: isResizable)
    }

    func foregroundColor(_ color: UIColor?) -> FLImage {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func environment(_ other: FLEnvironmentOverrides) -> FLImage {
        FLImage(
            image,
            contentMode: contentMode,
            overrides: overrides.merging(other),
            isResizable: isResizable
        )
    }
}

// MARK: - Hashable

public extension FLImage {
    static func == (lhs: FLImage, rhs: FLImage) -> Bool {
        lhs.contentMode == rhs.contentMode
            && lhs.overrides == rhs.overrides
            && lhs.isResizable == rhs.isResizable
            && (lhs.image === rhs.image || lhs.image == rhs.image)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(contentMode)
        hasher.combine(overrides)
        hasher.combine(isResizable)
        hasher.combine(image?.size.width)
        hasher.combine(image?.size.height)
    }
}

// MARK: - Layout

public struct FLImageLayout: FLLayout {
    public let size: CGSize
}

// A plain UIView wrapping a UIImageView, rather than a UIImageView subclass. Every other leaf view
// is a UIView subclass and inherits `init()`; UIImageView declares its own designated initialisers,
// which made this the one leaf needing a hand-written `init()` witness.
// MARK: - View

public final class FLImageView: UIView, FLNodeView {
    public typealias Node = FLImage

    private let imageView = UIImageView()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        // Frames are exact here, so an aspect-fill image must be clipped to them.
        clipsToBounds = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = bounds
    }

    public func update(node: FLImage, layout: FLImageLayout, context: FLRenderContext) {
        let tint = context.environment.applying(node.overrides).foregroundColor

        imageView.image = tint == nil ? node.image : node.image?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = tint
        imageView.contentMode = node.contentMode
    }
}
