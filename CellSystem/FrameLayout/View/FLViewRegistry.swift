import UIKit

@MainActor
final class FLViewRegistry {
    private var identifierToView: [AnyHashable: UIView] = [:]

    var count: Int { identifierToView.count }
    var identifiers: Set<AnyHashable> { Set(identifierToView.keys) }

    func view(for id: some Hashable) -> UIView? {
        identifierToView[AnyHashable(id)]
    }

    func contains(_ id: some Hashable) -> Bool {
        identifierToView[AnyHashable(id)] != nil
    }

    func register(_ view: UIView, as id: some Hashable) {
        identifierToView[AnyHashable(id)] = view
    }

    func removeAll() {
        identifierToView.removeAll(keepingCapacity: true)
    }
}
