import UIKit

@MainActor
final class FLViewRegistry {
    private var tagToView: [AnyHashable: UIView] = [:]

    var count: Int { tagToView.count }
    var tags: Set<AnyHashable> { Set(tagToView.keys) }

    func view(withTag tag: some Hashable) -> UIView? {
        tagToView[AnyHashable(tag)]
    }

    func button(withTag tag: some Hashable) -> UIControl? {
        view(withTag: tag) as? UIControl
    }

    func contains(_ tag: some Hashable) -> Bool {
        tagToView[AnyHashable(tag)] != nil
    }

    func register(_ view: UIView, withTag tag: some Hashable) {
        tagToView[AnyHashable(tag)] = view
    }

    func removeAll() {
        tagToView.removeAll(keepingCapacity: true)
    }
}
