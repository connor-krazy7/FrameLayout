import UIKit

struct FLButtonStyle: Hashable, Sendable {
    let pressedOpacity: CGFloat
    let pressedScale: CGFloat
    let animation: FLAnimation

    private init(pressedOpacity: CGFloat, pressedScale: CGFloat, animation: FLAnimation) {
        self.pressedOpacity = pressedOpacity
        self.pressedScale = pressedScale
        self.animation = animation
    }

    static func opacity(
        _ pressedOpacity: CGFloat = 0.6,
        animation: FLAnimation = .easeOut(0.12)
    ) -> FLButtonStyle {
        FLButtonStyle(pressedOpacity: pressedOpacity, pressedScale: 1, animation: animation)
    }

    static func scaling(
        _ pressedScale: CGFloat = 0.96,
        opacity pressedOpacity: CGFloat = 1,
        animation: FLAnimation = .easeOut(0.12)
    ) -> FLButtonStyle {
        FLButtonStyle(pressedOpacity: pressedOpacity, pressedScale: pressedScale, animation: animation)
    }
}

struct FLButtonLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLButton<Wrapped: FLNode, Tag: Hashable & Sendable>: FLNode {
    typealias View = FLButtonView<Wrapped, Tag>

    static var typeIdentifier: String { "button(\(Wrapped.typeIdentifier))" }

    let tag: Tag
    let style: FLButtonStyle
    let wrapped: Wrapped

    init(tag: Tag, style: FLButtonStyle = .opacity(), @FLNodeBuilder content: () -> Wrapped) {
        self.tag = tag
        self.style = style
        wrapped = content()
    }

    func layout(in context: FLContext) -> FLButtonLayout<Wrapped.Layout> {
        FLButtonLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLButtonView<Wrapped: FLNode, Tag: Hashable & Sendable>: UIControl, FLNodeView {
    typealias Node = FLButton<Wrapped, Tag>

    private let wrappedView = Wrapped.View()
    private var style = FLButtonStyle.opacity()

    override init(frame: CGRect) {
        super.init(frame: frame)

        wrappedView.isUserInteractionEnabled = false
        addSubview(wrappedView)
        isAccessibilityElement = true
        accessibilityTraits.insert(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }

            applyPressedState()
        }
    }

    func update(node: Node, layout: FLButtonLayout<Wrapped.Layout>, context: FLRenderContext) {
        context.registry?.register(self, withTag: node.tag)

        style = node.style
        isEnabled = context.isEnabled
        isUserInteractionEnabled = context.isEnabled
        accessibilityLabel = context.accessibilityLabel
        accessibilityTraits = context.isEnabled ? [.button] : [.button, .notEnabled]

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
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
