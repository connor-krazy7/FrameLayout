import Foundation
import SwiftUI
import Testing
import UIKit

@testable import FrameLayout

/// What reading a `UIColor` costs, by how the colour was made. Debug `-Onone` on the simulator, so read
/// the ratios; run-to-run variance on the pathological row is large enough that its magnitude is not
/// established — only that it is pathological.
///
/// | `cgColor` on | ns/op |
/// | --- | --- |
/// | the **first** read of a *freshly built* provider colour | **~10 000 000** |
/// | repeat reads of **one** provider colour | ~400 |
/// | a system colour (`.label`) | ~500 – 30 000, run to run |
/// | a component colour | ~210 |
/// | a resolved colour | ~130 |
/// | *for scale:* one `FLText` measure at width 200 | ~70 000 – 100 000 |
///
/// **The cost is per instance, on its first read — not per read.** A provider colour that has been read
/// before answers in ~400 ns; one that has not costs milliseconds, four orders of magnitude more than
/// anything else on the list and two more than measuring a line of text.
///
/// That makes this the *same* defect as the cache miss in
/// `FLColorProvenanceTests`, not a second one, and by far the larger half of its price. A token built
/// fresh per access is a new instance every time, so it pays the first-read cost on **every** access,
/// while a shared instance pays it once for the life of the process. `FLDecoratedView.update` reads
/// `cgColor` twice per update (`Modifiers/Decorated/FLDecorated.swift:143,146`) — once for
/// `layer.borderColor`, once to decide `drawsContent`, which also decides whether the view eats touches.
///
/// **Two reasons the magnitudes here are not to be quoted.** They are measured in a test process with no
/// window, so a first read has no trait environment to resolve against and may be paying for
/// diagnostics an app would not; and the system-colour and `FLText` rows move by more than 10× between
/// runs, which says the process is noisy enough that only the *ordering* is established. What is solid
/// across every run: repeat reads are hundreds of nanoseconds, a first read of a new provider colour is
/// milliseconds, and nothing else approaches either.
///
/// A hosted measurement inside a real view update is what would turn this into something actionable.
/// If it confirms, the fix is already prescribed by
/// [node-equality.md](../../../.claude/rules/architecture/node-equality.md): resolve through the
/// environment in `update`, which `FLDecoratedView` already holds, and the read lands on the resolved
/// row.
///
/// Resolution cost is recorded alongside because it is what any scheme deriving a stable identity from a
/// dynamic colour would pay per construction — the shape considered and rejected in issue #34:
///
/// | | ns/op |
/// | --- | --- |
/// | one `resolvedColor(with:)`, provider source | ~340 – 400 |
/// | resolving against two trait collections | ~870 – 1 350 |
/// | resolving against four | ~1 500 – 4 400 |
/// | *for scale:* one `FLText` construction | ~1 400 |
///
/// Asserts on semantics only, per the benchmark rule in
/// [testing.md](../../../.claude/rules/testing.md).
@Suite("Benchmark: colour reads by provenance", .serialized)
struct FLColorCostBenchmarks {
    private static let dynamic = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }

    private static let light = UITraitCollection(userInterfaceStyle: .light)

    private static let twoTraits: [UITraitCollection] = [
        light,
        UITraitCollection(userInterfaceStyle: .dark),
    ]

    private static let fourTraits: [UITraitCollection] = twoTraits.flatMap { style in
        [UIAccessibilityContrast.normal, .high].map { contrast in
            UITraitCollection(traitsFrom: [style, UITraitCollection(accessibilityContrast: contrast)])
        }
    }

    @Test("what a colour read costs, by provenance")
    func colourReadCost() {
        let resolved = Self.dynamic.resolvedColor(with: Self.light)

        #expect(resolved.cgColor.alpha == Self.dynamic.resolvedColor(with: Self.light).cgColor.alpha)
        #expect(Self.twoTraits.map { Self.dynamic.resolvedColor(with: $0) }.count == 2)
        #expect(Self.fourTraits.count == 4)

        FLBenchmark.printConfiguration("cgColor, which FLDecoratedView.update reads twice per update:")
        FLBenchmark.measure("first read of a fresh provider colour", iterations: 50) {
            UIColor { $0.userInterfaceStyle == .dark ? .white : .black }.cgColor.alpha > 0
        }
        FLBenchmark.measure("repeat reads of one provider colour", iterations: 200) {
            Self.dynamic.cgColor.alpha > 0
        }
        FLBenchmark.measure("a system colour", iterations: 200) { UIColor.label.cgColor.alpha > 0 }
        FLBenchmark.measure("a component colour", iterations: 200) { UIColor.red.cgColor.alpha > 0 }
        FLBenchmark.measure("a resolved colour", iterations: 200) { resolved.cgColor.alpha > 0 }

        FLBenchmark.printConfiguration("resolution, per construction:")
        FLBenchmark.measure("one resolvedColor(with:)") {
            Self.dynamic.resolvedColor(with: Self.light).hashValue != 0
        }
        FLBenchmark.measure("against two trait collections") {
            Self.twoTraits.map { Self.dynamic.resolvedColor(with: $0) }.count > 0
        }
        FLBenchmark.measure("against four trait collections") {
            Self.fourTraits.map { Self.dynamic.resolvedColor(with: $0) }.count > 0
        }

        FLBenchmark.printConfiguration("for scale:")
        FLBenchmark.measure("FLText construction from a String") {
            FLText("The quick brown fox").lineLimit == nil
        }
        FLBenchmark.measure("one FLText measure at width 200", iterations: 2_000) {
            FLText("The quick brown fox jumps over the lazy dog.")
                .layout(in: FLContext(width: 200)).size.height > 0
        }
    }
}
