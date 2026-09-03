import UIKit

/// A type-erased, `Sendable` box for the content id: `AnyHashable` is not `Sendable`, and a node must be.
public struct FLScrollIdentity: Sendable, Hashable {
    private let token: any Hashable & Sendable

    public init(_ token: some Hashable & Sendable) {
        self.token = token
    }

    /// The spelling `FLViewRegistry` stores a tag under. Re-boxing an `AnyHashable` is idempotent, so
    /// this matches a region tagged with the raw value rather than with an `FLScrollIdentity`.
    var tag: AnyHashable { AnyHashable(token) }

    public static func == (lhs: FLScrollIdentity, rhs: FLScrollIdentity) -> Bool {
        lhs.tag == rhs.tag
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }
}
