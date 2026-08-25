import UIKit

/// A type-erased, `Sendable` box for the content id: `AnyHashable` is not `Sendable`, and a node must be.
public struct FLScrollIdentity: Sendable, Hashable {
    private let token: any Hashable & Sendable

    init(_ token: some Hashable & Sendable) {
        self.token = token
    }

    public static func == (lhs: FLScrollIdentity, rhs: FLScrollIdentity) -> Bool {
        AnyHashable(lhs.token) == AnyHashable(rhs.token)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(token))
    }
}
