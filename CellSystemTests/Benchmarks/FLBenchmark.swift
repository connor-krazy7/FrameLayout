import Foundation

/// Timing harness for the benchmark suites. Not a correctness tool — nothing here fails a test on a
/// number, because timings on a shared machine are not reproducible enough to gate a build. The
/// benchmarks assert on *semantics* and print timings for a human to read.
enum FLBenchmark {
    /// Nanoseconds per operation. `operation` returns a value so the optimiser cannot discard the
    /// work it is supposed to be measuring.
    @discardableResult
    static func measure(_ label: String, iterations: Int = 10_000, _ operation: () -> Bool) -> Double {
        var sink = false
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            sink = operation() != sink
        }
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        let perOperation = Double(elapsed) / Double(iterations)

        print("  \(label.padding(toLength: 40, withPad: " ", startingAt: 0)) \(format(perOperation)) ns/op\(sink ? "" : "")")

        return perOperation
    }

    /// Print once at the top of a suite. A Debug test build is `-Onone`, which inflates every case and
    /// can bury the very difference a benchmark exists to show, so say so rather than let someone read
    /// the numbers as final.
    static func printConfiguration(_ title: String) {
        print("\n\(title)")
        #if DEBUG
        print("  ⚠︎ Debug build (-Onone): treat these as relative, not absolute. For comparable")
        print("    figures, set the test action's build configuration to Release in the scheme.")
        #endif
    }

    private static func format(_ nanoseconds: Double) -> String {
        nanoseconds < 10
            ? String(format: "%.2f", nanoseconds)
            : String(format: "%.0f", nanoseconds)
    }
}
