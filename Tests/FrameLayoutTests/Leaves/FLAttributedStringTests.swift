import Testing
import UIKit

@testable import FrameLayout

@Suite("Attributed string identity")
struct FLAttributedStringTests {
    private static let body = "a line of text long enough to wrap at this width"

    private static func coloured(_ colour: UIColor, over range: NSRange? = nil) -> NSAttributedString {
        let string = NSMutableAttributedString(string: body)
        string.addAttribute(
            .foregroundColor,
            value: colour,
            range: range ?? NSRange(location: 0, length: string.length)
        )

        return string
    }

    private static func identityHash(of value: FLAttributedString) -> Int {
        var hasher = Hasher()
        value.hashLayoutIdentity(into: &hasher)

        return hasher.finalize()
    }

    @Test("two colours are one layout identity, and two values")
    func colourIsNeutralButNotEqual() {
        let yellow = FLAttributedString(Self.coloured(.systemYellow))
        let green = FLAttributedString(Self.coloured(.systemGreen))

        #expect(yellow.isLayoutEquivalent(to: green))
        #expect(Self.identityHash(of: yellow) == Self.identityHash(of: green))

        // `==` is what a diff relies on, and it separates them. The *hash* does not: Foundation folds
        // the string into `NSAttributedString.hash` but not the attributes, which is a legal collision
        // and the reason node-equality.md says a miss is the worst case here.
        #expect(yellow != green)
        #expect(yellow.hashValue == green.hashValue)
    }

    @Test("a colour on part of the range is neutral too")
    func partialColourIsNeutral() {
        let half = NSRange(location: 0, length: Self.body.count / 2)
        let partly = FLAttributedString(Self.coloured(.systemYellow, over: half))
        let plain = FLAttributedString(NSAttributedString(string: Self.body))

        #expect(partly.isLayoutEquivalent(to: plain))
    }

    @Test("a font is not neutral")
    func fontStillSeparates() {
        let plain = FLAttributedString(NSAttributedString(string: Self.body))
        let large = FLAttributedString(
            NSAttributedString(string: Self.body, attributes: [.font: UIFont.systemFont(ofSize: 30)])
        )

        #expect(plain.isLayoutEquivalent(to: large) == false)
    }

    @Test("kerning is not neutral, since it moves glyphs")
    func kerningStillSeparates() {
        let plain = FLAttributedString(NSAttributedString(string: Self.body))
        let kerned = FLAttributedString(
            NSAttributedString(string: Self.body, attributes: [.kern: 4])
        )

        #expect(plain.isLayoutEquivalent(to: kerned) == false)
    }

    @Test("both string flavours arrive at the same value")
    func bridgesBothFlavours() {
        var swift = AttributedString(Self.body)
        swift.foregroundColor = .systemYellow

        let fromSwift = FLAttributedString(swift)
        let fromFoundation = FLAttributedString(Self.coloured(.systemYellow))

        #expect(fromSwift.underlying.string == fromFoundation.underlying.string)
        #expect(fromSwift.isLayoutEquivalent(to: fromFoundation))
        #expect(FLAttributedString(Self.body).underlying.string == Self.body)
    }

    @Test("construction snapshots the source")
    func constructionSnapshots() {
        let source = NSMutableAttributedString(string: "Hello")
        let value = FLAttributedString(source)

        source.append(NSAttributedString(string: " and more"))

        #expect(value.underlying.string == "Hello")
    }

    @Test("a colour changes no measured size through FLText")
    func colourChangesNoSize() {
        let context = FLContext(width: 120)
        let plain = FLText(NSAttributedString(string: Self.body)).layout(in: context)
        let yellow = FLText(Self.coloured(.systemYellow)).layout(in: context)

        #expect(plain == yellow)
    }

    @Test("one text under two baked-in colours is one cache entry")
    func colourNoLongerSplitsTheCache() {
        let cache = FLLayoutCache<FLText>()
        let context = FLContext(width: 120)

        _ = cache.layout(for: FLText(Self.coloured(.systemYellow)), in: context)
        _ = cache.layout(for: FLText(Self.coloured(.systemGreen)), in: context)

        #expect(cache.count == 1)
    }
}
