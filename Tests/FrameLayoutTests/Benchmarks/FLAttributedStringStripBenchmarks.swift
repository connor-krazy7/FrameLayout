import Foundation
import Testing
import UIKit

@testable import FrameLayout

/// What `FLAttributedString` costs to build, since it scans for neutral attributes on every
/// construction and strips them when it finds any. Debug `-Onone`, and run-to-run variance on a shared
/// machine is 1.5–2×, so only the ratios are meaningful:
///
/// | construction | ÷ one `FLText` measure |
/// | --- | --- |
/// | nothing to strip | ~1.7% |
/// | colour in 4 runs | ~5–6% |
/// | colour in 20 runs | ~11–17% |
///
/// Two properties held across every run. It is **flat in string length** — 90 000 characters costs what
/// 120 does — because `enumerateAttributes` walks runs rather than characters. And it scales with the
/// number of attribute runs, which is what to watch if the neutral list ever grows.
///
/// The trade: paid once per string, it saves a whole measure every time only a colour changed. A
/// consumer measuring without a layout cache pays it and gets nothing back, which is ~2% of a measure
/// and the reason it is worth keeping cheap.
///
/// A `Set` was tried in place of the `[NSAttributedString.Key]` scan and could not be distinguished
/// from it at this noise level. Do not switch without a Release build to measure in.
@Suite("Benchmark: FLAttributedString stripping", .serialized)
struct FLAttributedStringStripBenchmarks {
    private static func body(characters: Int) -> String {
        let unit = "The quick brown fox jumps over the lazy dog. "

        return String(repeating: unit, count: max(1, characters / unit.count))
    }

    private static func plain(_ characters: Int) -> NSAttributedString {
        NSAttributedString(
            string: body(characters: characters),
            attributes: [.font: UIFont.systemFont(ofSize: 14)]
        )
    }

    private static func coloured(_ characters: Int, runs: Int) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: plain(characters))
        let step = max(1, string.length / runs)

        for start in stride(from: 0, to: string.length, by: step * 2) {
            let length = min(step, string.length - start)
            string.addAttribute(
                .foregroundColor,
                value: UIColor.systemYellow,
                range: NSRange(location: start, length: length)
            )
        }

        return string
    }

    @Test("construction cost by whether there is anything to strip")
    func constructionCost() {
        let plainShort = Self.plain(120)
        let plainLong = Self.plain(90_000)
        let colouredShort = Self.coloured(120, runs: 4)
        let manyRuns = Self.coloured(120, runs: 20)

        #expect(FLAttributedString(colouredShort).isLayoutEquivalent(to: FLAttributedString(plainShort)))
        #expect(FLAttributedString(colouredShort) != FLAttributedString(plainShort))

        FLBenchmark.printConfiguration("FLAttributedString construction:")
        FLBenchmark.measure("nothing to strip, ~120 characters") {
            FLAttributedString(plainShort).underlying.length > 0
        }
        FLBenchmark.measure("nothing to strip, 90 000 characters") {
            FLAttributedString(plainLong).underlying.length > 0
        }
        FLBenchmark.measure("colour in 4 runs, ~120 characters") {
            FLAttributedString(colouredShort).underlying.length > 0
        }
        FLBenchmark.measure("colour in 20 runs, ~120 characters") {
            FLAttributedString(manyRuns).underlying.length > 0
        }

        FLBenchmark.printConfiguration("for scale:")
        FLBenchmark.measure("the snapshot alone") {
            NSAttributedString(attributedString: plainShort).length > 0
        }
        FLBenchmark.measure("one FLText measure at width 200", iterations: 2_000) {
            FLText(plainShort).layout(in: FLContext(width: 200)).size.height > 0
        }
    }
}
