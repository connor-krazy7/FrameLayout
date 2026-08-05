import Foundation

public protocol ThenCustomisable: AnyObject {}

public extension ThenCustomisable {
    func then(_ modifyClosure: (inout Self) -> Void) -> Self {
        var mutableSelf = self
        modifyClosure(&mutableSelf)
        return mutableSelf
    }
}

extension NSObject: ThenCustomisable {}
