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

    @Test("mutating the source string afterwards does not change the node")
    func constructionSnapshotsTheString() {
        let source = NSMutableAttributedString(string: "Hello")
        let node = FLText(source)
        let hashBefore = node.hashValue

        source.append(NSAttributedString(string: " and more text besides"))

        #expect(node.attributedText.underlying.string == "Hello")
        #expect(node.hashValue == hashBefore)
        #expect(node == FLText(NSAttributedString(string: "Hello")))
    }

    // The same snapshot on the paths that rebuild a node, since `multilineTextAlignment` hands the
    // private initialiser a mutable string of its own.
    @Test("a rebuilt node snapshots too, so its string cannot be mutated through a downcast")
    func modifiersSnapshotAsWell() {
        let node = FLText("Hello").multilineTextAlignment(.center)
        let hashBefore = node.hashValue

        (node.attributedText.underlying as? NSMutableAttributedString)?
            .append(NSAttributedString(string: " and more"))

        #expect(node.attributedText.underlying.string == "Hello")
        #expect(node.hashValue == hashBefore)
    }

    @Test("a cache keyed before a mutation still answers for the original content")
    func cacheStaysConsistentAcrossAMutation() {
        let cache = FLLayoutCache<FLText>()
        let context = FLContext(width: 300)
        let source = NSMutableAttributedString(string: "Hello")
        let node = FLText(source)

        _ = cache.layout(for: node, in: context)
        source.append(NSAttributedString(string: " and more text besides"))

        _ = cache.layout(for: node, in: context)

        #expect(cache.count == 1)
        #expect(cache.layout(for: node, in: context) == FLText("Hello").layout(in: context))
    }
}
