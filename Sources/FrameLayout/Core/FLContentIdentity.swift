import UIKit

/// A type-erased, `Sendable` box for a content id: `AnyHashable` is not `Sendable`, and a node must be.
public struct FLContentIdentity: Sendable, Hashable {
    private let token: any Hashable & Sendable

    public init(_ token: some Hashable & Sendable) {
        self.token = token
    }

    /// The spelling `FLViewRegistry` stores a tag under. Re-boxing an `AnyHashable` is idempotent, so
    /// this matches a region tagged with the raw value rather than with an `FLContentIdentity`.
    var tag: AnyHashable { AnyHashable(token) }

    public static func == (lhs: FLContentIdentity, rhs: FLContentIdentity) -> Bool {
        lhs.tag == rhs.tag
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }
}
