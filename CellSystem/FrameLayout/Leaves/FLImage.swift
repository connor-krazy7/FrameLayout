import UIKit

struct FLImageLayout: FLLayout {
    let size: CGSize
}

/// Reports the image's own point size, like a non-resizable SwiftUI `Image`. Call `resizable()` to
/// let it accept a proposal instead; every other sizing behaviour comes from modifiers.
struct FLImage: FLNode {
    typealias View = FLImageView

    static var typeIdentifier: String { "image" }

    let image: UIImage?
    let contentMode: UIView.ContentMode
    let tintColor: UIColor?
    let isResizable: Bool

    init(
        _ image: UIImage?,
        contentMode: UIView.ContentMode = .scaleAspectFill,
        tintColor: UIColor? = nil
    ) {
        self.init(image, contentMode: contentMode, tintColor: tintColor, isResizable: false)
    }

    private init(
        _ image: UIImage?,
        contentMode: UIView.ContentMode,
        tintColor: UIColor?,
        isResizable: Bool
    ) {
        self.image = image
        self.contentMode = contentMode
        self.tintColor = tintColor
        self.isResizable = isResizable
    }

    /// Only the image knows it can be resampled, so willingness to take a proposal has to live here
    /// rather than in a modifier.
    func resizable() -> FLImage {
        FLImage(image, contentMode: contentMode, tintColor: tintColor, isResizable: true)
    }

    /// A tint implies template rendering, which is applied when the view is configured.
    func tint(_ color: UIColor?) -> FLImage {
        FLImage(image, contentMode: contentMode, tintColor: color, isResizable: isResizable)
    }

    func layout(in context: FLContext) -> FLImageLayout {
        guard isResizable else { return FLImageLayout(size: intrinsicSize) }

        return FLImageLayout(
            size: CGSize(
                width: extent(context.width, ideal: intrinsicSize.width),
                height: extent(context.height, ideal: intrinsicSize.height)
            )
        )
    }

    private var intrinsicSize: CGSize {
        (image?.size).or(.zero)
    }

    private func extent(_ proposal: FLProposal, ideal: CGFloat) -> CGFloat {
        switch proposal {
        case .unspecified: ideal
        case .minimum: 0
        case .maximum: .infinity
        case let .exact(value): value
        }
    }
}

extension FLImage {
    static func == (lhs: FLImage, rhs: FLImage) -> Bool {
        lhs.contentMode == rhs.contentMode
            && lhs.tintColor == rhs.tintColor
            && lhs.isResizable == rhs.isResizable
            && (lhs.image === rhs.image || lhs.image == rhs.image)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(contentMode)
        hasher.combine(tintColor)
        hasher.combine(isResizable)
        hasher.combine(image?.size.width)
        hasher.combine(image?.size.height)
    }
}

// A plain UIView wrapping a UIImageView, rather than a UIImageView subclass. Every other leaf view
// is a UIView subclass and inherits `init()`; UIImageView declares its own designated initialisers,
// which made this the one leaf needing a hand-written `init()` witness.
final class FLImageView: UIView, FLNodeView {
    typealias Node = FLImage

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Frames are exact here, so an aspect-fill image must be clipped to them.
        clipsToBounds = true
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = bounds
    }

    func update(node: FLImage, layout: FLImageLayout, environment: FLEnvironment) {
        let tint = node.tintColor.or(environment.foregroundColor)

        imageView.image = tint == nil ? node.image : node.image?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = tint
        imageView.contentMode = node.contentMode
    }
}
