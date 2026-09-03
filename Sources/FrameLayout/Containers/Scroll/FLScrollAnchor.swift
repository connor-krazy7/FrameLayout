import UIKit

/// Where a scroll region starts. `.offset` names the position; `.element` names a `tag(_:)`ed descendant
/// to bring into view, so a stored photo id restores the right photo where an index or an offset would not
/// survive an insertion or a change of width.
///
/// An `.offset` is applied as given; an `.element` position is derived, so it is clamped to what the region
/// can reach. It resolves against the tagged view, which exists because `FLScroll` builds every child on
/// apply, and falls back to `.zero` when the tag names nothing inside the region.
public enum FLScrollAnchor: Sendable, Hashable {
    case offset(FLPoint)
    case element(id: FLScrollIdentity, alignment: FLAlignment)

    /// `.topLeading` puts the element's own leading edge at the viewport's, which is the paging position.
    public static func element(
        _ id: some Hashable & Sendable,
        alignment: FLAlignment = .topLeading
    ) -> FLScrollAnchor {
        .element(id: FLScrollIdentity(id), alignment: alignment)
    }
}
