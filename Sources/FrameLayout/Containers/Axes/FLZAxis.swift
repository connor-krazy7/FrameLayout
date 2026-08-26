import UIKit

public enum FLZAxis: FLStackAxis {
    public typealias Alignment = FLAlignment

    public static var defaultAlignment: FLAlignment { .center }
    public static var distributesAlongAxis: Bool { false }

    public static func extent(of size: CGSize) -> CGFloat { size.width }
    public static func proposal(in context: FLContext) -> FLProposal { .unspecified }

    public static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext { context }

    public static func resolve(
        children: FLStackChildren,
        alignment: FLAlignment,
        in context: FLContext
    ) -> FLStackGeometry {
        guard children.count > 0 else { return .empty }

        let size = children.children.reduce(CGSize.zero) {
            CGSize(width: Swift.max($0.width, $1.size.width), height: Swift.max($0.height, $1.size.height))
        }
        let childFrames = children.children.map { child in
            CGRect(
                origin: alignment.origin(
                    childSize: child.size,
                    containerSize: size,
                    direction: context.layoutDirection
                ),
                size: child.size
            )
        }

        return FLStackGeometry(size: size, childFrames: childFrames)
    }
}
