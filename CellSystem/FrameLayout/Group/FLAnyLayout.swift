import UIKit

struct FLAnyLayout: FLLayout {
    let size: CGSize

    private let base: any FLLayout
    private let isEqual: @Sendable (any FLLayout) -> Bool

    init<Wrapped: FLLayout>(_ layout: Wrapped) {
        size = layout.size
        base = layout
        isEqual = { other in
            guard let other = other as? Wrapped else { return false }
            return other == layout
        }
    }

    func unwrap<Wrapped: FLLayout>(as type: Wrapped.Type) -> Wrapped? {
        base as? Wrapped
    }

    static func == (lhs: FLAnyLayout, rhs: FLAnyLayout) -> Bool {
        lhs.isEqual(rhs.base)
    }
}
