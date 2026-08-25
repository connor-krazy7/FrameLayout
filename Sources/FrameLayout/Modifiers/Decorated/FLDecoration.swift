import UIKit

public struct FLDecoration: Sendable, Hashable, WithCustomisable {
    public var backgroundColor: UIColor = .clear
    public var shape: FLShape = .rectangle
    public var corners: FLCorners = .all
    public var cornerCurve: FLCornerCurve = .circular
    public var borderColor: UIColor = .clear
    public var borderWidth: CGFloat = 0
    public var clipsToBounds: Bool = false
}
