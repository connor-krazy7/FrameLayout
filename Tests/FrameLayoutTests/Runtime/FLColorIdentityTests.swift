import Testing
import UIKit
@testable import FrameLayout

/// Whether a `UIColor` stored on a node compares and hashes equal across two separate accesses, which
/// decides whether a consumer's layout cache hits at all.
///
/// | | `===` | `==` | hash |
/// | --- | --- | --- | --- |
/// | `.label`, two separate accesses | yes | yes | yes |
/// | two `UIColor(dynamicProvider:)`, identical closures | no | **no** | **no** |
/// | one `UIColor(dynamicProvider:)`, against itself | yes | yes | yes |
/// | two component colours, same components | — | yes | yes |
/// | `.label` vs `.label.resolvedColor(with:)` | — | no | — |
///
/// A closure cannot be compared — nothing about two blocks tells `isEqual:` whether they compute the
/// same thing — so `UIColor` falls back to instance equality for dynamic colours. Pointer identity does
/// short-circuit, so **one shared instance** is equal to itself and hashes stably, which is the whole
/// fix: a dynamic colour must be built once and reused, not rebuilt per access. A system colour is safe
/// for exactly that reason, being a cached singleton.
///
/// This suite asserts a **platform** behaviour, which is unusual here and deliberate. The singleton
/// identity of `.label` is load-bearing for cache hit rates across the package, and the inequality of
/// two separately built dynamic colours is what the rule in
/// `.claude/rules/architecture/node-equality.md` exists to warn about. Either changing should fail
/// loudly rather than silently costing — or silently returning — every consumer their hit rate.
@Suite("Colour identity")
struct FLColorIdentityTests {
    /// Built once, the way a consumer's theme colour must be. The `let` is the point: a computed
    /// `static var` with the same body would hand back a new instance per access and read identically
    /// at the call site.
    private static let sharedDynamic = UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    private static func freshDynamic() -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? .white : .black }
    }

    @Test("a system colour is one cached instance, so it compares and hashes equal")
    func systemColoursAreSingletons() {
        #expect(UIColor.label === UIColor.label)
        #expect(UIColor.label == UIColor.label)
        #expect(UIColor.label.hashValue == UIColor.label.hashValue)

        #expect(UIColor.systemBlue === UIColor.systemBlue)
        #expect(UIColor.systemBlue == UIColor.systemBlue)
        #expect(UIColor.systemBlue.hashValue == UIColor.systemBlue.hashValue)
    }

    // Pinning the constraint, not a desired behaviour. If this ever starts passing, the rule about
    // reusing one instance can be relaxed and this test should be revisited rather than deleted.
    @Test("two dynamic colours built from identical closures never compare equal")
    func freshDynamicColoursDiffer() {
        let first = Self.freshDynamic()
        let second = Self.freshDynamic()

        #expect(first !== second)
        #expect(first != second)
        #expect(first.hashValue != second.hashValue)
    }

    @Test("one shared dynamic instance compares equal to itself and hashes stably")
    func sharedDynamicColourIsStable() {
        let colour = Self.sharedDynamic

        #expect(colour === Self.sharedDynamic)
        #expect(colour == Self.sharedDynamic)
        #expect(colour.hashValue == Self.sharedDynamic.hashValue)
    }

    @Test("a colour built from components compares by content")
    func componentColoursCompareByContent() {
        let first = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        let second = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    // Which is why resolution belongs in `update` — `FLTextView.update` resolves through
    // `context.environment` — and must not be hoisted into node construction as an optimisation.
    @Test("a resolved colour is a different colour from its dynamic source")
    func resolvingProducesADifferentColour() {
        let resolved = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))

        #expect(UIColor.label != resolved)
    }

    @Test("distinct colours separate")
    func distinctColoursSeparate() {
        #expect(UIColor.label != UIColor.secondaryLabel)
        #expect(UIColor.systemBlue != UIColor.systemRed)
    }

    // The consequence the rule is actually about, measured through the cache a consumer is told to
    // build rather than inferred from `==`.
    @Test("a node carrying one shared dynamic colour hits the cache; fresh instances miss")
    func cacheHitsOnlyForASharedInstance() {
        let context = FLContext(width: 100, height: 40)

        let shared = FLLayoutCache<FLColor>()

        _ = shared.layout(for: FLColor(Self.sharedDynamic), in: context)
        _ = shared.layout(for: FLColor(Self.sharedDynamic), in: context)

        #expect(shared.count == 1)

        let fresh = FLLayoutCache<FLColor>()

        _ = fresh.layout(for: FLColor(Self.freshDynamic()), in: context)
        _ = fresh.layout(for: FLColor(Self.freshDynamic()), in: context)

        #expect(fresh.count == 2)
    }

    // A colour reaches a key through more than `FLColor`. `FLDecoration` is the one a consumer hits by
    // way of `.background(_:)` on a chain-rooted cache.
    @Test("a decoration carrying one shared instance compares equal")
    func decorationsCompareOnTheSharedInstance() {
        #expect(
            FLDecoration(backgroundColor: Self.sharedDynamic)
                == FLDecoration(backgroundColor: Self.sharedDynamic)
        )
        #expect(
            FLDecoration(backgroundColor: Self.freshDynamic())
                != FLDecoration(backgroundColor: Self.freshDynamic())
        )
    }

    @Test("a system colour on a node hits the cache")
    func systemColourNodesHit() {
        let cache = FLLayoutCache<FLColor>()
        let context = FLContext(width: 100, height: 40)

        _ = cache.layout(for: FLColor(.label), in: context)
        _ = cache.layout(for: FLColor(.label), in: context)

        #expect(cache.count == 1)
    }
}
