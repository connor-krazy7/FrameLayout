import Testing
import UIKit
@testable import FrameLayout

@Suite("Text hashing")
struct FLTextHashingTests {
    // Our `==` treats distinct instances with equal content as equal, so the hash has to be
    // content-based or the Hashable contract breaks. NSAttributedString's own hash is.
    @Test("distinct instances with the same content hash equally")
    func contentBasedHashing() {
        let a = FLText(NSAttributedString(string: "Hello"))
        let b = FLText(NSAttributedString(string: "Hello"))

        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("different text hashes differently")
    func differentTextDiffers() {
        #expect(FLText("Hello").hashValue != FLText("Goodbye").hashValue)
    }

    @Test("styling and text modifiers take part in the hash")
    func stylingAffectsHash() {
        let plain = FLText("Hello")

        #expect(plain.hashValue != plain.font(.systemFont(ofSize: 30)).hashValue)
        #expect(plain.hashValue != plain.lineLimit(2).hashValue)
        #expect(plain.hashValue != plain.lineBreakMode(.byTruncatingTail).hashValue)
    }

    @Test("a cache keyed on text distinguishes content and styling")
    func cacheDistinguishes() {
        let cache = FLLayoutCache<FLText>()
        let context = FLContext(width: 300)

        _ = cache.layout(for: FLText("Hello"), in: context)
        _ = cache.layout(for: FLText("Hello"), in: context)
        #expect(cache.count == 1)

        _ = cache.layout(for: FLText("Hello").font(.systemFont(ofSize: 30)), in: context)
        #expect(cache.count == 2)
    }
}
