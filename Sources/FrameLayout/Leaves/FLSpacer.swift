import UIKit

// MARK: - Node

public struct FLSpacer: FLNode {
    public typealias View = FLSpacerView

    public var isSpacer: Bool { true }

    public let minLength: CGFloat

    public init(minLength: CGFloat = 0) {
        self.minLength = minLength
    }

    // A spacer reports only its minimum. Its real extent is assigned by the enclosing stack, which
    // is what lets it absorb leftover space without being re-measured.
    public func layout(in context: FLContext) -> FLSpacerLayout {
        FLSpacerLayout(size: CGSize(width: minLength, height: minLength))
    }
}

// MARK: - Layout

public struct FLSpacerLayout: FLLayout {
    public let size: CGSize
}

// MARK: - View

public final class FLSpacerView: UIView, FLNodeView {
    public typealias Node = FLSpacer

    public override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLSpacer, layout: FLSpacerLayout, context: FLRenderContext) {}
}
