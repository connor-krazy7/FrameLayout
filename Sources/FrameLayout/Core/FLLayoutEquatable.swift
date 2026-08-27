import UIKit

/// Whether two values produce the same geometry, which is coarser than `==`. A conformance must satisfy
/// `a.isLayoutEquivalent(to: b)` ⟹ `a.layout(in: c) == b.layout(in: c)` for every `c` — on the whole
/// layout, not its size. See `node-equality.md` for when narrowing is sound.
public protocol FLLayoutEquatable: Hashable {
    func isLayoutEquivalent(to other: Self) -> Bool
    func hashLayoutIdentity(into hasher: inout Hasher)
}

public extension FLLayoutEquatable {
    func isLayoutEquivalent(to other: Self) -> Bool { self == other }
    func hashLayoutIdentity(into hasher: inout Hasher) { hash(into: &hasher) }
}
