import Testing
import UIKit

@testable import FrameLayout

/// Samples the two implications `FLLayoutEquatable` owes, over variants and contexts; `node-equality.md`
/// states them. Compares whole layouts rather than sizes — a size-only assertion passes while a child
/// frame diverges.
@Suite("Layout identity contract")
struct FLLayoutContractTests {
    private static let contexts: [FLContext] = [
        FLContext(width: 200),
        FLContext(width: 120),
        FLContext(width: 40),
        FLContext(width: nil),
        FLContext(width: 200, height: 60),
        FLContext(width: 200, layoutDirection: .rightToLeft),
        FLContext(width: 200, contentSizeCategory: UIContentSizeCategory.extraExtraLarge.rawValue),
        FLContext(width: 200, environment: FLEnvironment(foregroundColor: .systemRed)),
        FLContext(width: 200, environment: FLEnvironment(font: .systemFont(ofSize: 24))),
    ]

    /// The guards are what stop this passing vacuously: without a pair that is equivalent-but-unequal
    /// the narrowing is untested, and without a pair that separates, a conformance returning `true`
    /// throughout would pass.
    private static func assertContract<Node: FLNode>(
        _ label: String,
        _ variants: [Node],
        expectsNarrowing: Bool = true,
        expectsSeparation: Bool = true
    ) {
        var sawNarrowedPair = false
        var sawSeparatedPair = false

        for (i, a) in variants.enumerated() {
            for (j, b) in variants.enumerated() {
                let pair = "\(label)[\(i)] against [\(j)]"

                if a == b {
                    #expect(a.isLayoutEquivalent(to: b), "equal values must be layout-equivalent: \(pair)")
                }

                guard a.isLayoutEquivalent(to: b) else {
                    sawSeparatedPair = true
                    continue
                }

                if a != b {
                    sawNarrowedPair = true
                }

                #expect(
                    identityHash(of: a) == identityHash(of: b),
                    "layout-equivalent values must share an identity hash: \(pair)"
                )

                for (k, context) in contexts.enumerated() {
                    #expect(
                        a.layout(in: context) == b.layout(in: context),
                        "layout-equivalent values must produce equal layouts: \(pair), context[\(k)]"
                    )
                }
            }
        }

        if expectsNarrowing {
            #expect(sawNarrowedPair, "\(label): no unequal-but-equivalent pair, so narrowing is untested")
        }

        if expectsSeparation {
            #expect(sawSeparatedPair, "\(label): every pair was equivalent, so separation is untested")
        }
    }

    private static func identityHash(of node: some FLNode) -> Int {
        var hasher = Hasher()
        node.hashLayoutIdentity(into: &hasher)

        return hasher.finalize()
    }

    @Test("FLText: colour is neutral, font and text are not")
    func text() {
        Self.assertContract("FLText", [
            FLText("a line of text that wraps at the narrower widths"),
            FLText("a line of text that wraps at the narrower widths").foregroundColor(.systemRed),
            FLText("a line of text that wraps at the narrower widths").foregroundColor(.systemBlue),
            FLText("a line of text that wraps at the narrower widths").font(.systemFont(ofSize: 30)),
            FLText("a line of text that wraps at the narrower widths").lineLimit(1),
            FLText("different words entirely, of a different length"),
        ])
    }

    // The one type that cannot separate: it narrows to nothing, so every pair is equivalent.
    @Test("FLColor: every colour is equivalent to every other")
    func colour() {
        Self.assertContract(
            "FLColor",
            [FLColor(.systemRed), FLColor(.systemBlue), FLColor(.label)],
            expectsSeparation: false
        )
    }

    @Test("FLImage: content mode and tint are neutral, resizability is not")
    func image() {
        let image = UIImage(systemName: "star")

        Self.assertContract("FLImage", [
            FLImage(image),
            FLImage(image).foregroundColor(.systemRed),
            FLImage(image).contentMode(.scaleAspectFill),
            FLImage(image).resizable(),
        ])
    }

    @Test("FLDecorated: the whole decoration is neutral, the child is not")
    func decorated() {
        Self.assertContract("FLDecorated", [
            FLText("a bubble").padding(10).background(.systemBlue, in: .roundedRectangle(4)),
            FLText("a bubble").padding(10).background(.systemRed, in: .roundedRectangle(20)),
            FLText("a bubble").padding(10).background(.systemRed, in: .roundedRectangle(20), corners: .top),
            FLText("a bubble").padding(16).background(.systemBlue, in: .roundedRectangle(4)),
        ])
    }

    @Test("FLScroll: the configuration is neutral, the axis and content are not")
    func scroll() {
        Self.assertContract("FLScroll", [
            FLScroll(.vertical) { FLText("scrolling content") },
            FLScroll(.vertical) { FLText("scrolling content") }.bounces(false),
            FLScroll(.vertical) { FLText("scrolling content") }.initialContentOffset(CGPoint(x: 0, y: 40)),
            FLScroll(.horizontal) { FLText("scrolling content") },
        ])
    }

    @Test("the pass-through wrappers carry nothing of their own")
    func passThroughWrappers() {
        Self.assertContract("FLTagged", [
            FLText("tagged").tag("one"),
            FLText("tagged").tag("two"),
            FLText("different").tag("one"),
        ])

        Self.assertContract("FLAdjusted", [
            FLText("adjusted").opacity(1),
            FLText("adjusted").opacity(0.2),
            FLText("different").opacity(1),
        ])

        Self.assertContract("FLDisabled", [
            FLText("disabled").disabled(false),
            FLText("disabled").disabled(true),
            FLText("different").disabled(false),
        ])
    }

    @Test("FLEnvironmentOverride: a colour override is neutral, a font override is not")
    func environmentOverride() {
        Self.assertContract("FLEnvironmentOverride", [
            FLText("inherited").foregroundColor(nil).environment(FLEnvironmentOverrides()),
            FLText("inherited").environment(FLEnvironmentOverrides(foregroundColor: .systemRed)),
            FLText("inherited").environment(FLEnvironmentOverrides(foregroundColor: .systemBlue)),
            FLText("inherited").environment(FLEnvironmentOverrides(font: .systemFont(ofSize: 30))),
        ])
    }
}
