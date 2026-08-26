import UIKit

public protocol FLStackAxis: Sendable {
    associatedtype Alignment: Sendable, Hashable

    static var defaultAlignment: Alignment { get }

    /// Whether children compete for a bounded extent along this axis. False for Z, where they overlay.
    static var distributesAlongAxis: Bool { get }

    static func extent(of size: CGSize) -> CGFloat
    static func proposal(in context: FLContext) -> FLProposal
    static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext

    static func resolve(
        children: FLStackChildren,
        alignment: Alignment,
        in context: FLContext
    ) -> FLStackGeometry
}
