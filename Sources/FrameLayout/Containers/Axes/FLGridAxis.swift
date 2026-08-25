import UIKit

/// What a grid needs from its orientation. Separate from `FLStackAxis` because a grid has two live axes:
/// the one whose tracks are declared, and the one lines accumulate along.
public protocol FLGridAxis: Sendable {
    static var gridToken: String { get }

    static func flowExtent(of size: CGSize) -> CGFloat
    static func crossExtent(of size: CGSize) -> CGFloat
    static func crossProposal(in context: FLContext) -> FLProposal
    static func size(flow: CGFloat, cross: CGFloat) -> CGSize
    static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint
    static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext
}
