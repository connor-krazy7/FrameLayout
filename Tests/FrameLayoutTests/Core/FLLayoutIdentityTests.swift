import Testing
import UIKit

@testable import FrameLayout

/// That `FLLayoutEquatable`'s default is `==`, that the narrowed conformances drop what they should, and
/// that `FLLayoutKey` combines both halves.
@Suite("Layout identity")
struct FLLayoutIdentityTests {
    private static func padded(_ inset: CGFloat) -> FLPadded<FLText> {
        FLText("a line").padding(inset)
    }

    // `FLPadded` takes the default, so this exercises the default rather than an override.
    @Test("the default is equality, in both directions")
    func defaultFollowsEquality() {
        let node = Self.padded(10)
        let same = Self.padded(10)
        let other = Self.padded(20)

        #expect(node.isLayoutEquivalent(to: same))
        #expect(node.isLayoutEquivalent(to: other) == false)
        #expect(node == same)
        #expect(node != other)
    }

    @Test("the default hash is the Hashable hash")
    func defaultHashFollowsHashable() {
        let node = Self.padded(10)

        var identity = Hasher()
        node.hashLayoutIdentity(into: &identity)

        var value = Hasher()
        node.hash(into: &value)

        #expect(identity.finalize() == value.finalize())
    }

    @Test("a context ignores colour and keeps everything else")
    func contextDropsColourOnly() {
        let context = FLContext(width: 200)
        let coloured = FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed))
        let wider = FLContext(width: 300)
        let fonted = FLContext(width: 200, environment: FLEnvironment(font: .systemFont(ofSize: 30)))
        let large = FLContext(width: 200, contentSizeCategory: UIContentSizeCategory.extraLarge.rawValue)
        let rightToLeft = FLContext(width: 200, layoutDirection: .rightToLeft)

        #expect(context.isLayoutEquivalent(to: coloured))
        #expect(context.isLayoutEquivalent(to: wider) == false)
        #expect(context.isLayoutEquivalent(to: fonted) == false)
        #expect(context.isLayoutEquivalent(to: large) == false)
        #expect(context.isLayoutEquivalent(to: rightToLeft) == false)
    }

    @Test("a key matches when both halves do, and separates when either differs")
    func keyCombinesBothHalves() {
        let context = FLContext(width: 200)
        let key = FLLayoutKey(node: Self.padded(10), context: context)

        #expect(key == FLLayoutKey(node: Self.padded(10), context: context))
        #expect(key.hashValue == FLLayoutKey(node: Self.padded(10), context: context).hashValue)

        #expect(key != FLLayoutKey(node: Self.padded(20), context: context))
        #expect(key != FLLayoutKey(node: Self.padded(10), context: FLContext(width: 300)))
    }

    // The acceptance criterion for the context half: one geometry, one key, under two colours.
    @Test("a context differing only in colour is the same key")
    func colourNoLongerSeparatesKeys() {
        let plain = FLLayoutKey(node: Self.padded(10), context: FLContext(width: 200))
        let coloured = FLLayoutKey(
            node: Self.padded(10),
            context: FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed))
        )

        #expect(plain == coloured)
        #expect(plain.hashValue == coloured.hashValue)
    }

    @Test("the cache separates what still matters")
    func cacheSeparatesLayoutAffectingInputsOnly() {
        let cache = FLLayoutCache<FLPadded<FLText>>()
        let context = FLContext(width: 200)

        _ = cache.layout(for: Self.padded(10), in: context)
        _ = cache.layout(for: Self.padded(10), in: context)

        #expect(cache.count == 1)

        _ = cache.layout(for: Self.padded(20), in: context)
        _ = cache.layout(for: Self.padded(10), in: FLContext(width: 300))

        #expect(cache.count == 3)

        _ = cache.layout(
            for: Self.padded(10),
            in: FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed))
        )

        #expect(cache.count == 3, "a colour in the environment must not add an entry")
    }

    // A structural wrapper takes the default, which is full `==` — so it does not recurse into a
    // child's narrowed identity and a chain-rooted key stays coarse. #8's second deliverable is what
    // closes this; `FLStack` and `FLGrid` need `FLGroup` to gain layout identity first.
    @Test("narrowing does not propagate through a wrapper that takes the default")
    func narrowingStopsAtADefaultWrapper() {
        let plain = FLText("a line")
        let coloured = FLText("a line").foregroundColor(.systemRed)

        #expect(plain.isLayoutEquivalent(to: coloured))
        #expect(plain.padding(10).isLayoutEquivalent(to: coloured.padding(10)) == false)
    }
}
