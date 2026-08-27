import Testing
import UIKit

@testable import FrameLayout

/// That a colour changes no measured size, and that no colour reaches the string `layout(in:)` measures.
@Suite("Text measurement ignores colour")
struct FLTextMeasurementColourTests {
    private static let wrapping = FLText(
        "a line long enough to wrap at this width, so the measurement has real work to do"
    )

    private static func context(foregroundColor: UIColor?) -> FLContext {
        FLContext(width: 120, environment: FLEnvironment(foregroundColor: foregroundColor))
    }

    @Test("two environments differing only in colour measure the same")
    func inheritedColourDoesNotChangeSize() {
        let red = Self.wrapping.layout(in: Self.context(foregroundColor: .systemRed))
        let blue = Self.wrapping.layout(in: Self.context(foregroundColor: .systemBlue))
        let none = Self.wrapping.layout(in: Self.context(foregroundColor: nil))

        #expect(red == blue)
        #expect(red == none)
        #expect(red.size.height > 20, "the fixture must actually wrap for this to mean anything")
    }

    @Test("colour set on the text itself does not change size")
    func overriddenColourDoesNotChangeSize() {
        let plain = Self.wrapping
        let coloured = Self.wrapping.foregroundColor(.systemGreen)

        #expect(
            coloured.layout(in: Self.context(foregroundColor: nil))
                == plain.layout(in: Self.context(foregroundColor: nil))
        )
    }

    @Test("a colour attribute already on the string does not change size")
    func attributedColourDoesNotChangeSize() {
        let string = "a line long enough to wrap at this width, so the measurement has real work to do"
        let plain = FLText(NSAttributedString(string: string))
        let coloured = FLText(
            NSAttributedString(string: string, attributes: [.foregroundColor: UIColor.systemGreen])
        )

        #expect(
            coloured.layout(in: Self.context(foregroundColor: nil))
                == plain.layout(in: Self.context(foregroundColor: nil))
        )
    }

    // Not redundant with the three above: if a colour reappeared in the measured string those sizes
    // would still match, and only this fails.
    @Test("the measured string carries a font and no colour")
    func measuredStringOmitsColour() {
        let environment = FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30))
        let measured = Self.wrapping.measuredText(in: environment)

        #expect(measured.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 30))
        #expect(measured.attribute(.foregroundColor, at: 0, effectiveRange: nil) == nil)
    }

    @Test("the rendered string still carries both")
    func resolvedStringKeepsColour() {
        let environment = FLEnvironment(foregroundColor: .systemRed, font: .systemFont(ofSize: 30))
        let resolved = Self.wrapping.resolvedText(in: environment)

        #expect(resolved.attribute(.font, at: 0, effectiveRange: nil) as? UIFont == .systemFont(ofSize: 30))
        #expect(resolved.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor == .systemRed)
    }

    // Two, not one: the key is the whole `FLContext`. Not a stale assertion — #2 is what makes it one.
    @Test("colour still splits the cache, because the key is the whole context")
    func colourStillSplitsTheCache() {
        let cache = FLLayoutCache<FLText>()

        _ = cache.layout(for: Self.wrapping, in: Self.context(foregroundColor: .systemRed))
        _ = cache.layout(for: Self.wrapping, in: Self.context(foregroundColor: .systemBlue))

        #expect(cache.count == 2)
    }
}
