import UIKit

struct FLSpacerLayout: FLLayout {
    let size: CGSize
}

struct FLSpacer: FLNode {
    typealias View = FLSpacerView

    static var typeIdentifier: String { "spacer" }

    var isSpacer: Bool { true }

    let minLength: CGFloat

    init(minLength: CGFloat = 0) {
        self.minLength = minLength
    }

    // A spacer reports only its minimum. Its real extent is assigned by the enclosing stack, which
    // is what lets it absorb leftover space without being re-measured.
    func layout(in context: FLContext) -> FLSpacerLayout {
        FLSpacerLayout(size: CGSize(width: minLength, height: minLength))
    }
}

final class FLSpacerView: UIView, FLNodeView {
    typealias Node = FLSpacer

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLSpacer, layout: FLSpacerLayout, environment: FLEnvironment) {}
}
