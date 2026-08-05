import SwiftUI
import UIKit

extension UIColor: FLNodeProviding {
    public var flNode: FLColor { FLColor(self) }
}

extension Color: FLNodeProviding {
    public var flNode: FLColor { FLColor(UIColor(self)) }
}

public extension FLGroupBuilder {
    static func buildExpression(_ color: UIColor) -> FLSingle<FLColor> {
        FLSingle(node: color.flNode)
    }

    static func buildExpression(_ color: Color) -> FLSingle<FLColor> {
        FLSingle(node: color.flNode)
    }
}

public extension FLNodeBuilder {
    static func buildExpression(_ color: UIColor) -> FLColor {
        color.flNode
    }

    static func buildExpression(_ color: Color) -> FLColor {
        color.flNode
    }
}
