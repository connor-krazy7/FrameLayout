import Foundation
import Testing
import UIKit

@testable import FrameLayout

/// What the placement pass in `FLFrame` costs. A bounded frame whose child answers a different size than
/// the frame resolves to has to measure that child twice: once against the original proposal, once
/// against the box the frame settled on. The pass is skipped when the two proposals match, so the
/// question is how often it fires and what it costs when it does. Debug `-Onone`, iPhone 17 simulator:
///
/// | case                                         | before the pass | with the pass |
/// | -------------------------------------------- | --------------- | ------------- |
/// | bounded frame, bound clamps                  | 966 ns          | 1 790 ns      |
/// | bounded frame, bound does not clamp          | 964 ns          | 1 012 ns      |
/// | unbounded frame                              | 524 ns          | 523 ns        |
/// | three clamping frames inside a clamped stack | 12 518 ns       | 45 373 ns     |
/// | the nested demo conversation row             | 1 356 µs        | 1 322 µs      |
///
/// A clamping frame roughly doubles and nesting compounds, but realistic content pays nothing: a frame is
/// only charged when its bound actually bites, and the conversation row's frames do not clamp.
@MainActor
@Suite("Frame placement cost")
struct FLFramePlacementBenchmarks {
    private let context = FLContext(width: 320)

    private var portrait: UIImage { FixtureSwatch.portrait }
    private var landscape: UIImage { FixtureSwatch.landscape }

    @Test("timings")
    func timings() {
        FLBenchmark.printConfiguration("FLFrame placement")

        func measure(_ label: String, _ operation: @escaping () -> CGSize) {
            FLBenchmark.measure(label, iterations: 2_000) { operation().height > 0 }
        }

        let clamping = FLImage(portrait)
            .resizable()
            .aspectRatio(0.5, contentMode: .fit)
            .frame(maxHeight: 100)
        let notClamping = FLImage(landscape)
            .resizable()
            .aspectRatio(16.0 / 9, contentMode: .fit)
            .frame(maxHeight: 400)
        let unbounded = FLImage(landscape)
            .resizable()
            .aspectRatio(16.0 / 9, contentMode: .fit)
        let nestedClamping = FLVStack(spacing: 4) {
            clamping
            clamping
            clamping
        }
        .frame(maxHeight: 260)

        measure("bounded, clamps (pass fires)") { clamping.layout(in: context).size }
        measure("bounded, no clamp (pass skipped)") { notClamping.layout(in: context).size }
        measure("unbounded baseline") { unbounded.layout(in: context).size }
        measure("three clamping frames in a clamped stack") { nestedClamping.layout(in: context).size }
        measure("nested fixture row") {
            FixtureRow(item: FixtureItem.sample).node.layout(in: context).size
        }
    }

    @Test("a clamped bounded frame keeps its reported size while the child fits inside it")
    func semantics() {
        let node = FLImage(portrait).resizable().aspectRatio(0.5, contentMode: .fit).frame(maxHeight: 100)
        let layout = node.layout(in: context)

        #expect(layout.size.height == 100)
        #expect(layout.wrapped.size.height <= layout.size.height)
    }
}
