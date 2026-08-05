import UIKit

public struct FLAnyLayout: FLLayout {
    public let size: CGSize

    private let base: any FLLayout
    private let isEqual: @Sendable (any FLLayout) -> Bool

    public init<Wrapped: FLLayout>(_ layout: Wrapped) {
        size = layout.size
        base = layout
        isEqual = { other in
            guard let other = other as? Wrapped else { return false }
            return other == layout
        }
    }

    public func unwrap<Wrapped: FLLayout>(as type: Wrapped.Type) -> Wrapped? {
        base as? Wrapped
    }

    public static func == (lhs: FLAnyLayout, rhs: FLAnyLayout) -> Bool {
        lhs.isEqual(rhs.base)
    }
}
