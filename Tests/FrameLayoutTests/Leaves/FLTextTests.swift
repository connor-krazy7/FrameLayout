import Testing
import UIKit
@testable import FrameLayout

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
