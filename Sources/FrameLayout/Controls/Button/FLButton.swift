import UIKit

// MARK: - Node

public struct FLButton<Wrapped: FLNode, Tag: Hashable & Sendable>: FLNode {
    public typealias Layout = Wrapped.Layout
    public typealias View = FLButtonView<Wrapped, Tag>

    public let tag: Tag
    public let style: FLButtonStyle
    public let wrapped: Wrapped

    public init(tag: Tag, style: FLButtonStyle = .opacity(), @FLNodeBuilder content: () -> Wrapped) {
        self.tag = tag
        self.style = style
        wrapped = content()
    }

    public func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context)
    }
}

// MARK: - FLLayoutEquatable

public extension FLButton {
    func isLayoutEquivalent(to other: FLButton<Wrapped, Tag>) -> Bool {
        wrapped.isLayoutEquivalent(to: other.wrapped)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        wrapped.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - View

public final class FLButtonView<Wrapped: FLNode, Tag: Hashable & Sendable>: UIControl, FLNodeView {
    public typealias Node = FLButton<Wrapped, Tag>

    private let wrappedView = Wrapped.View()
    private var style = FLButtonStyle.opacity()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        wrappedView.isUserInteractionEnabled = false
        addSubview(wrappedView)
        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }

            applyPressedState()
        }
    }

    public func update(node: Node, layout: Wrapped.Layout, context: FLRenderContext) {
        context.registry?.registerView(self, withTag: node.tag)

        style = node.style
        isEnabled = context.isEnabled
        isUserInteractionEnabled = context.isEnabled
        accessibilityLabel = context.accessibilityLabel
        accessibilityTraits = context.isEnabled ? [.button] : [.button, .notEnabled]

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout, context: context)
        applyPressedState()
    }

    private func applyPressedState() {
        let opacity = isHighlighted ? style.pressedOpacity : 1
        let scale = isHighlighted ? style.pressedScale : 1

        style.animation.run {
            self.wrappedView.alpha = opacity
            self.wrappedView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
