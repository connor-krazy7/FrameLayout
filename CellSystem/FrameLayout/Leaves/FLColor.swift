import UIKit

struct FLColorLayout: FLLayout {
    let size: CGSize
}

struct FLColor: FLNode {
    typealias View = FLColorView

    static var typeIdentifier: String { "color" }

    let color: UIColor

    init(_ color: UIColor) {
        self.color = color
    }

    func layout(in context: FLContext) -> FLColorLayout {
        FLColorLayout(
            size: CGSize(width: Self.extent(context.width), height: Self.extent(context.height))
        )
    }

    // A fill has no content of its own: its ideal and minimum are zero, its maximum unbounded.
    private static func extent(_ proposal: FLProposal) -> CGFloat {
        switch proposal {
        case .unspecified, .minimum: 0
        case .maximum: .infinity
        case let .exact(value): value
        }
    }
}

final class FLColorView: UIView, FLNodeView {
    typealias Node = FLColor

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLColor, layout: FLColorLayout, environment: FLEnvironment) {
        backgroundColor = node.color
    }
}
