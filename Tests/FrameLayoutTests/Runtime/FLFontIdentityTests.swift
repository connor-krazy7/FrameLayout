import Testing
import UIKit

@testable import FrameLayout

/// Whether a `UIFont` arriving through `FLContext` compares and hashes equal across two separate
/// accesses. `font` is layout-**affecting**, so unlike a colour it cannot be excluded from a layout
/// key — it is in the key at every root — and its equality therefore decides hit rate outright.
///
/// | | `===` | `==` | hash |
/// | --- | --- | --- | --- |
/// | `.systemFont(ofSize: 17)`, two accesses | yes | yes | yes |
/// | `.preferredFont(forTextStyle: .body)`, two accesses | yes | yes | yes |
/// | two `UIFont(descriptor:size:)` from equivalent descriptors | yes | yes | yes |
/// | two `UIFont(name:size:)`, same face | yes | yes | yes |
/// | `.systemFont(ofSize: 17)` vs `.systemFont(ofSize: 17, weight: .regular)` | **no** | yes | yes |
/// | `.systemFont(ofSize: 17)` vs `.systemFont(ofSize: 18)` | no | no | no |
/// | `.body` vs `.body` at `.extraLarge` | no | no | no |
///
/// This is the opposite verdict from `UIColor`, and the reason is worth naming rather than the
/// conclusion: a font is fully described by its descriptor, which is comparable data, while a dynamic
/// colour is described by a closure, which is not. So `UIFont` compares by content and there is
/// nothing for a consumer to do.
///
/// **Row 5 is the load-bearing one.** UIKit also caches fonts, so every "two accesses" row above is
/// pointer-identical and each of those `==` results could be explained by identity alone. Two
/// *distinct* instances comparing and hashing equal is what proves the relation is content-based, and
/// therefore that the key survives the font cache missing.
///
/// Measured identically on iOS 17.5 and 26.1, the ends of the supported range. Like
/// `FLColorIdentityTests` this asserts a **platform** behaviour deliberately: a font that stopped
/// comparing by content would cost every consumer their hit rate with no diagnostic, and there is no
/// share-one-instance mitigation available, because a font is normally built per call rather than held
/// as a `static let`.
@MainActor
@Suite("Font identity")
struct FLFontIdentityTests {
    @Test("a system font is one cached instance, so it compares and hashes equal")
    func systemFontsAreCached() {
        #expect(UIFont.systemFont(ofSize: 17) === UIFont.systemFont(ofSize: 17))
        #expect(UIFont.systemFont(ofSize: 17) == UIFont.systemFont(ofSize: 17))
        #expect(UIFont.systemFont(ofSize: 17).hashValue == UIFont.systemFont(ofSize: 17).hashValue)

        #expect(UIFont.boldSystemFont(ofSize: 13) == UIFont.boldSystemFont(ofSize: 13))
        #expect(
            UIFont.systemFont(ofSize: 17, weight: .semibold)
                == UIFont.systemFont(ofSize: 17, weight: .semibold)
        )
    }

    @Test("a Dynamic Type font compares equal across two accesses")
    func preferredFontsCompareEqual() {
        let first = UIFont.preferredFont(forTextStyle: .body)
        let second = UIFont.preferredFont(forTextStyle: .body)

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    @Test("a font built from a descriptor or a name compares equal across two builds")
    func constructedFontsCompareEqual() {
        let descriptor = UIFont.systemFont(ofSize: 17).fontDescriptor

        #expect(UIFont(descriptor: descriptor, size: 17) == UIFont(descriptor: descriptor, size: 17))
        #expect(UIFont(name: "Helvetica", size: 17) == UIFont(name: "Helvetica", size: 17))
    }

    // The row that separates content equality from the font cache happening to hand back one object.
    // Two spellings of the same face produce two distinct instances that still compare equal, so the
    // relation is content-based and a key on `font` survives the font cache missing.
    @Test("two distinct instances of the same face compare and hash equal")
    func distinctInstancesOfOneFaceCompareEqual() {
        let plain = UIFont.systemFont(ofSize: 17)
        let explicit = UIFont.systemFont(ofSize: 17, weight: .regular)

        #expect(plain !== explicit)
        #expect(plain == explicit)
        #expect(plain.hashValue == explicit.hashValue)
    }

    @Test("genuinely different fonts separate")
    func differentFontsSeparate() {
        #expect(UIFont.systemFont(ofSize: 17) != UIFont.systemFont(ofSize: 18))
        #expect(UIFont.systemFont(ofSize: 17) != UIFont.boldSystemFont(ofSize: 17))
    }

    // A Dynamic Type font carries its resolved point size, so two content size categories are two
    // fonts. That is correct, and it is why `contentSizeCategory` earns its place in the key beside it.
    @Test("one text style at two content size categories is two fonts")
    func contentSizeCategorySeparatesPreferredFonts() {
        let standard = UIFont.preferredFont(forTextStyle: .body)
        let large = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraLarge)
        )

        #expect(standard != large)
    }

    // The consequence, measured through the cache rather than inferred from `==`. Two contexts built
    // from separate calls for the same font are one key, which is what makes a consumer's cache work
    // without them having to hold their fonts anywhere.
    @Test("a font obtained twice is one cache entry, not two")
    func fontsRebuiltPerAccessStillHit() {
        let text = FLText("a line of text whose font arrives through the environment")

        let system = FLLayoutCache<FLText>()

        _ = system.layout(for: text, in: Self.context(font: .systemFont(ofSize: 17)))
        _ = system.layout(for: text, in: Self.context(font: .systemFont(ofSize: 17)))

        #expect(system.count == 1)

        let preferred = FLLayoutCache<FLText>()

        _ = preferred.layout(for: text, in: Self.context(font: .preferredFont(forTextStyle: .body)))
        _ = preferred.layout(for: text, in: Self.context(font: .preferredFont(forTextStyle: .body)))

        #expect(preferred.count == 1)

        let differing = FLLayoutCache<FLText>()

        _ = differing.layout(for: text, in: Self.context(font: .systemFont(ofSize: 17)))
        _ = differing.layout(for: text, in: Self.context(font: .systemFont(ofSize: 25)))

        #expect(differing.count == 2)
    }

    private static func context(font: UIFont) -> FLContext {
        FLContext(width: 200, environment: FLEnvironment(font: font))
    }
}
