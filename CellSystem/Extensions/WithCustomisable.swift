import Foundation

protocol WithCustomisable {}

extension WithCustomisable {
    func with(_ modifyClosure: (inout Self) -> Void) -> Self {
        var mutableSelf = self
        modifyClosure(&mutableSelf)
        return mutableSelf
    }
}

extension Array: WithCustomisable {}
extension Dictionary: WithCustomisable {}
extension Set: WithCustomisable {}
