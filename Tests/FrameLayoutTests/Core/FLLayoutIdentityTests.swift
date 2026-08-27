import Testing
import UIKit

@testable import FrameLayout

/// That `FLLayoutEquatable`'s default is `==`, and that `FLLayoutKey` therefore behaves exactly as a
/// key on `(node, context)` until a type narrows it.
@Suite("Layout identity")
struct FLLayoutIdentityTests {
    private static func bubble(radius: CGFloat) -> FLDecorated<FLPadded<FLText>> {
        FLText("a bubble")
            .padding(10)
            .background(.systemBlue, in: .roundedRectangle(radius))
    }

    @Test("the default is equality, in both directions")
    func defaultFollowsEquality() {
        let node = Self.bubble(radius: 4)
        let same = Self.bubble(radius: 4)
        let other = Self.bubble(radius: 20)

        #expect(node.isLayoutEquivalent(to: same))
        #expect(node.isLayoutEquivalent(to: other) == false)
        #expect(node == same)
        #expect(node != other)
    }

    @Test("the default hash is the Hashable hash")
    func defaultHashFollowsHashable() {
        let node = Self.bubble(radius: 4)

        var identity = Hasher()
        node.hashLayoutIdentity(into: &identity)

        var value = Hasher()
        node.hash(into: &value)

        #expect(identity.finalize() == value.finalize())
    }

    @Test("FLContext takes the default too")
    func contextFollowsEquality() {
        let context = FLContext(width: 200)
        let same = FLContext(width: 200)
        let wider = FLContext(width: 300)
        let coloured = FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed))

        #expect(context.isLayoutEquivalent(to: same))
        #expect(context.isLayoutEquivalent(to: wider) == false)
        #expect(context.isLayoutEquivalent(to: coloured) == false)
    }

    @Test("a key matches when both halves do, and separates when either differs")
    func keyCombinesBothHalves() {
        let context = FLContext(width: 200)
        let key = FLLayoutKey(node: Self.bubble(radius: 4), context: context)

        #expect(key == FLLayoutKey(node: Self.bubble(radius: 4), context: context))
        #expect(key.hashValue == FLLayoutKey(node: Self.bubble(radius: 4), context: context).hashValue)

        #expect(key != FLLayoutKey(node: Self.bubble(radius: 20), context: context))
        #expect(key != FLLayoutKey(node: Self.bubble(radius: 4), context: FLContext(width: 300)))
    }

    // Not a stale assertion — #2 is what makes these equal.
    @Test("a context differing only in colour is a different key")
    func colourStillSeparatesKeys() {
        let plain = FLLayoutKey(node: Self.bubble(radius: 4), context: FLContext(width: 200))
        let coloured = FLLayoutKey(
            node: Self.bubble(radius: 4),
            context: FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed))
        )

        #expect(plain != coloured)
    }

    @Test("the cache keys on it without changing what it separates")
    func cacheBehaviourIsUnchanged() {
        let cache = FLLayoutCache<FLDecorated<FLPadded<FLText>>>()
        let context = FLContext(width: 200)

        _ = cache.layout(for: Self.bubble(radius: 4), in: context)
        _ = cache.layout(for: Self.bubble(radius: 4), in: context)

        #expect(cache.count == 1)

        _ = cache.layout(for: Self.bubble(radius: 20), in: context)
        _ = cache.layout(for: Self.bubble(radius: 4), in: FLContext(width: 300))

        #expect(cache.count == 3)
    }
}
