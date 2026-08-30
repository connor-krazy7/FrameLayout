import Testing
import UIKit

@testable import FrameLayout

/// These pass on any simulator and only mean something on the minimum, where a stored `CGPoint` traps.
/// `make test-minimum` is what exercises them; see `node-equality.md`.
@MainActor
@Suite("Scroll hashing")
struct FLScrollHashingTests {
    private static func scroll(offset: FLPoint) -> FLScroll<FLText> {
        FLScroll(.vertical) { FLText("scrolling content") }.initialContentOffset(offset)
    }

    @Test("a configuration hashes")
    func configurationHashes() {
        _ = FLScrollConfiguration().hashValue
        _ = FLScrollConfiguration().with { $0.initialContentOffset = FLPoint(x: 4, y: 8) }.hashValue
    }

    @Test("a node hashes, and a set of them keeps both")
    func nodeHashes() {
        let near = Self.scroll(offset: .zero)
        let far = Self.scroll(offset: FLPoint(x: 0, y: 40))

        #expect(near.hashValue == Self.scroll(offset: .zero).hashValue)
        #expect(near != far)
        #expect(Set([near, far, Self.scroll(offset: .zero)]).count == 2)
    }

    @Test("the offset survives the round trip through its components")
    func offsetRoundTrips() {
        let offset = FLPoint(x: 12.5, y: -3)
        let configuration = FLScrollConfiguration().with { $0.initialContentOffset = offset }

        #expect(configuration.initialContentOffset == offset)
        #expect(Self.scroll(offset: offset).configuration.initialContentOffset == offset)
    }

    @Test("it stays layout-neutral")
    func offsetIsLayoutNeutral() {
        #expect(Self.scroll(offset: .zero).isLayoutEquivalent(to: Self.scroll(offset: FLPoint(x: 0, y: 40))))
    }
}
