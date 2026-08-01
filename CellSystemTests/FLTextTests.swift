import Testing
import UIKit
@testable import CellSystem

@Suite("Text measurement")
struct FLTextTests {
    private static let sample = """
        Every node here is a single-child generic wrapper, so the content tree and the view tree \
        are the same type by construction.
        """

    private static var font: UIFont { .systemFont(ofSize: 16) }

    private func text(lineLimit: Int) -> FLText {
        FLText(Self.sample)
            .lineLimit(lineLimit)
            .lineBreakMode(.byTruncatingTail)
    }

    private func context(width: CGFloat) -> FLContext {
        FLContext(width: width, environment: FLEnvironment(font: Self.font))
    }

    private func height(lineLimit: Int, width: CGFloat = 224) -> CGFloat {
        text(lineLimit: lineLimit).layout(in: context(width: width)).size.height
    }

    // Heights are ceil()ed totals, and a system font's line height is not an integer, so n lines is
    // only approximately n x one line. Tolerate a point of rounding per comparison.
    @Test("a line limit scales the measured height with the number of lines")
    func lineLimitScalesHeight() {
        let single = height(lineLimit: 1)

        #expect(single > 0)
        #expect(abs(height(lineLimit: 2) - single * 2) <= 1)
        #expect(abs(height(lineLimit: 3) - single * 3) <= 2)
    }

    @Test("each additional allowed line adds height, monotonically")
    func heightIsMonotonic() {
        let heights = [1, 2, 3, 4].map { height(lineLimit: $0) }

        #expect(zip(heights, heights.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("a line limit measures shorter than unlimited")
    func limitIsShorterThanUnlimited() {
        #expect(height(lineLimit: 2) < height(lineLimit: 0))
    }

    @Test("unlimited measures the same as a limit at or above the real line count")
    func unlimitedMatchesGenerousLimit() {
        #expect(height(lineLimit: 0) == height(lineLimit: 50))
    }

    @Test("empty text measures to zero")
    func emptyText() {
        #expect(FLText("").layout(in: context(width: 300)).size == .zero)
    }

    @Test("line limit and break mode participate in equality")
    func limitAffectsEquality() {
        #expect(text(lineLimit: 1) != text(lineLimit: 2))
        #expect(text(lineLimit: 2) == text(lineLimit: 2))
    }

    @Test("the minimum is the widest whitespace-delimited run")
    func minimumWidth() {
        let node = FLText(Self.sample)
        let environment = FLEnvironment(font: Self.font)
        let minimum = node.layout(in: FLContext(width: .minimum, environment: environment)).size.width
        let ideal = node.layout(in: FLContext(width: .unspecified, environment: environment)).size.width

        #expect(minimum > 0)
        #expect(minimum < ideal)
    }

    @Test("a single unbreakable word has no smaller minimum than its own width")
    func singleWordMinimum() {
        let node = FLText("construction")
        let environment = FLEnvironment(font: Self.font)

        let minimum = node.layout(in: FLContext(width: .minimum, environment: environment)).size.width
        let ideal = node.layout(in: FLContext(width: .unspecified, environment: environment)).size.width

        #expect(minimum == ideal)
    }

    @Test("text shrinks no further than its minimum inside a narrow stack")
    func minimumIsRespectedByAStack() {
        let node = FLHStack(spacing: 0) {
            FLText("construction")
            FLText("construction")
        }
        let environment = FLEnvironment(font: Self.font)
        let wordWidth = FLText("construction")
            .layout(in: FLContext(width: .minimum, environment: environment))
            .size
            .width
        let layout = node.layout(in: FLContext(width: 60, environment: environment))

        #expect(layout.childFrames.allSatisfy { $0.width >= wordWidth })
    }

    @Test("narrower proposals never exceed the proposed width")
    func respectsProposedWidth() {
        for width in [CGFloat(80), 160, 224, 320] {
            #expect(text(lineLimit: 0).layout(in: context(width: width)).size.width <= width)
        }
    }
}

@Suite("Text styling comes from the environment")
struct FLTextStylingTests {
    @Test("with nothing set, UILabel's own defaults apply")
    func fallsBackToDefaults() {
        let node = FLText("Hello")
        let resolved = node.resolvedText(in: .default)

        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == FLText.defaultFont)
        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == FLText.defaultColor)
        #expect(FLText.defaultFont.pointSize == UIFont.labelFontSize)
    }

    @Test("an inherited font and colour are applied when resolving")
    func inheritsFromEnvironment() {
        let environment = FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30))
        let resolved = FLText("Hello").resolvedText(in: environment)

        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 30))
        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemRed)
    }

    // The point of putting font in the environment rather than only at update time.
    @Test("an inherited font changes measurement")
    func fontAffectsMeasurement() {
        let node = FLText("Hello")
        let small = node.layout(in: FLContext(width: 300, environment: FLEnvironment(font: .systemFont(ofSize: 10))))
        let large = node.layout(in: FLContext(width: 300, environment: FLEnvironment(font: .systemFont(ofSize: 40))))

        #expect(small.size.height < large.size.height)
        #expect(small.size.width < large.size.width)
    }

    @Test("attributes already on the string win over everything")
    func existingAttributesWin() {
        let attributed = NSAttributedString(
            string: "Hello",
            attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.systemGreen]
        )
        let node = FLText(attributed).font(.systemFont(ofSize: 40)).foregroundColor(.systemBlue)
        let resolved = node.resolvedText(in: FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30)))

        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemGreen)
        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 12))
    }

    // The gain from uniform storage: a partially-styled string fills only what it is missing, where
    // the previous all-or-nothing design refused the environment outright.
    @Test("a partially-styled string inherits only the attributes it lacks")
    func partialStylingFillsGaps() {
        let attributed = NSAttributedString(string: "Hello", attributes: [.foregroundColor: UIColor.systemGreen])
        let node = FLText(attributed)
        let resolved = node.resolvedText(in: FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30)))

        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemGreen)
        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 30))
    }

    @Test("gap filling is per range, not all or nothing")
    func fillsPerRange() {
        let mixed = NSMutableAttributedString(string: "abcdef")
        mixed.addAttribute(.foregroundColor, value: UIColor.systemGreen, range: NSRange(location: 0, length: 3))

        let resolved = FLText(mixed).resolvedText(in: FLEnvironment(foregroundColor: .systemRed))

        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemGreen)
        #expect(resolved.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? UIColor == .systemRed)
    }

    @Test("alignment leaves font and colour free to inherit")
    func alignmentDoesNotBakeStyling() {
        let node = FLText("Hello").multilineTextAlignment(.center)
        let resolved = node.resolvedText(in: FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30)))

        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 30))
        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemRed)

        let style = resolved.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.alignment == .center)
    }

    @Test("an override wins over what it inherits, and merges with siblings")
    func overrideWinsAndMerges() {
        let overrides = FLEnvironmentOverrides(foregroundColor: .systemBlue, font: nil)
        let inherited = FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 20))
        let applied = inherited.applying(overrides)

        #expect(applied.foregroundColor == .systemBlue)
        #expect(applied.font == .systemFont(ofSize: 20))
    }

    // FLText has its own font/foregroundColor returning FLText, so text modifiers still chain after
    // them — the same shape as SwiftUI's `Text.font(_:) -> Text`.
    @Test("styling on the text keeps the FLText type, so lineLimit still chains")
    func stylingKeepsTheTextType() {
        let node = FLText("Hello")
            .font(.systemFont(ofSize: 20))
            .foregroundColor(.systemRed)
            .lineLimit(2)
            .lineBreakMode(.byTruncatingTail)

        #expect(node.overrides.font == .systemFont(ofSize: 20))
        #expect(node.overrides.foregroundColor == .systemRed)
        #expect(node.lineLimit == 2)
        #expect(node.lineBreakMode == .byTruncatingTail)
    }

    @Test("text modifiers preserve styling set before them")
    func textModifiersPreserveStyling() {
        let styled = FLText("Hello").font(.systemFont(ofSize: 20))

        #expect(styled.lineLimit(3).overrides.font == .systemFont(ofSize: 20))
        #expect(styled.multilineTextAlignment(.center).lineLimit == 0)
    }

    @Test("styling on the text beats what it inherits")
    func leafStylingWinsOverEnvironment() {
        let inherited = FLEnvironment(foregroundColor: .systemGreen, font: .systemFont(ofSize: 10))
        let node = FLText("Hello").foregroundColor(.systemRed)
        let resolved = node.resolvedText(in: inherited)

        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemRed)
        // the font was not set on the text, so it still inherits
        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 10))
    }

    @Test("an override propagates through wrappers to a nested leaf")
    func propagatesThroughWrappers() {
        let styled = FLVStack(spacing: 4) {
            FLText("Hello")
        }
        .padding(10)
        .font(.systemFont(ofSize: 40))

        let plain = FLVStack(spacing: 4) {
            FLText("Hello")
        }
        .padding(10)

        let context = FLContext(width: 300)

        #expect(styled.layout(in: context).size.height > plain.layout(in: context).size.height)
    }
}

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
