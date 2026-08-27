import Testing
import UIKit

@testable import FrameLayout

/// That a layout measured off the main thread is the layout measured on it, for every kind of node the
/// package can measure, and that concurrent measurement of one node agrees with itself.
///
/// Off-main measurement is the premise of the package rather than a feature of it, and until this suite
/// existed nothing asserted it: no test anywhere in `Tests/` ran on another thread, so
/// `FLLayoutComputer`'s `!Thread.isMainThread` precondition never fired and the allowlist in
/// `.claude/rules/architecture/concurrency.md` — what a measurement may touch — rested on "the package
/// does this and has not crashed" rather than on a result.
///
/// Two of the assertions are about **platform** behaviour rather than about FL, and are deliberate for
/// the same reason `FLColorIdentityTests` asserts one: `NSAttributedString.boundingRect` and the
/// `UIFont` class properties are called from `FLText.layout(in:)` on an arbitrary cooperative-pool
/// thread. Neither is documented as safe there in a way this package controls. If either ever stops
/// being safe, the text measurement path is what breaks, and it should break here first.
///
/// What this suite does **not** establish: that a measurement is fast off-main, or that the pool is not
/// saturated by many of them. That needs a benchmark timing N concurrent measurements, which does not
/// exist — see the same rule.
@Suite("Off-main measurement")
struct FLOffMainMeasurementTests {
    /// `FixtureRow.Body` is opaque, so its layout can only be named through the associated type.
    private typealias RowLayout = FLComposed<FixtureRow>.Layout

    private static let context = FLContext(width: 200)

    private static var paragraph: FLText {
        FLText("a paragraph long enough to wrap across several lines when it is measured at 200 points")
            .lineLimit(0)
    }

    /// The four-level composite from `Fixtures/`, so the subject is a realistic tree rather than a leaf.
    private static var composite: FLComposed<FixtureRow> {
        FixtureRow(item: .sample).node
    }

    /// `Thread.isMainThread` is unavailable from an asynchronous context in this target, so the two
    /// halves of the thread check are spelled differently: this synchronous `@MainActor` function is
    /// its own context and may read it, while the off-main side uses `pthread_main_np()`, a C call
    /// carrying no such restriction.
    ///
    /// Worth knowing rather than relying on: the identical read inside a `Task.detached` closure
    /// compiles without a diagnostic in the framework target, which is where
    /// `FLLayoutComputer`'s precondition lives. `Package.swift` gives both targets the same settings,
    /// so the difference comes from the Xcode project, where the framework sets
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` and the test target does not.
    @MainActor
    private static func isOnMainThread() -> Bool {
        Thread.isMainThread
    }

    private static func offMain<Node: FLNode>(_ node: Node) async -> Node.Layout {
        await Task.detached(priority: .userInitiated) {
            node.layout(in: context)
        }.value
    }

    // MARK: - The premise

    @Test("a detached task really does leave the main thread")
    func detachedTaskIsNotOnTheMainThread() async {
        let wasOnMainThread = await Task.detached { pthread_main_np() != 0 }.value

        #expect(wasOnMainThread == false)
        #expect(await Self.isOnMainThread())
    }

    @Test("text measured off the main thread matches text measured on it")
    func textAgreesAcrossThreads() async {
        let node = Self.paragraph
        let offMain = await Self.offMain(node)
        let onMain = await MainActor.run { node.layout(in: Self.context) }

        #expect(offMain.size.height > 0)
        #expect(offMain == onMain)
    }

    @Test("a four-level composite measured off the main thread matches, frames included")
    func compositeAgreesAcrossThreads() async {
        let node = Self.composite
        let offMain = await Self.offMain(node)
        let onMain = await MainActor.run { node.layout(in: Self.context) }

        #expect(offMain.size.height > 0)
        #expect(offMain == onMain)
    }

    @Test("FLLayoutComputer returns what a direct call returns, and its precondition holds")
    func computerAgreesWithADirectCall() async {
        let node = Self.paragraph
        let computed = await FLLayoutComputer.layout(node, in: Self.context)
        let direct = await MainActor.run { node.layout(in: Self.context) }

        #expect(computed == direct)
    }

    // MARK: - Under contention

    @Test("sixty-four concurrent measurements of one node all agree")
    func concurrentMeasurementsAgree() async {
        let node = Self.paragraph
        let expected = await MainActor.run { node.layout(in: Self.context) }

        let layouts = await withTaskGroup(of: FLTextLayout.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { node.layout(in: Self.context) }
            }

            return await group.reduce(into: [FLTextLayout]()) { $0.append($1) }
        }

        #expect(layouts.count == 64)
        #expect(layouts.allSatisfy { $0 == expected })
    }

    @Test("concurrent measurements of distinct nodes do not interfere")
    func concurrentDistinctMeasurementsAgree() async {
        let items = (0 ..< 32).map { FixtureItem.sample.with(badges: ["badge \($0)"]) }
        let expected = await MainActor.run {
            items.map { FixtureRow(item: $0).node.layout(in: Self.context) }
        }

        let layouts = await withTaskGroup(of: (Int, RowLayout).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask { (index, FixtureRow(item: item).node.layout(in: Self.context)) }
            }

            return await group.reduce(into: [Int: RowLayout]()) { $0[$1.0] = $1.1 }
        }

        #expect(layouts.count == items.count)
        #expect(items.indices.allSatisfy { layouts[$0] == expected[$0] })
    }

    @Test("a cache probed concurrently for one key ends with one entry, and every answer agrees")
    func concurrentCacheProbesAgree() async {
        let cache = FLLayoutCache<FLText>()
        let node = Self.paragraph
        let expected = await MainActor.run { node.layout(in: Self.context) }

        let layouts = await withTaskGroup(of: FLTextLayout.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { cache.layout(for: node, in: Self.context) }
            }

            return await group.reduce(into: [FLTextLayout]()) { $0.append($1) }
        }

        #expect(layouts.allSatisfy { $0 == expected })
        #expect(cache.count == 1)
    }

    @Test("a cache filled concurrently from distinct keys keeps every one of them")
    func concurrentCacheFillKeepsEveryKey() async {
        let cache = FLLayoutCache<FLText>()
        let nodes = (0 ..< 32).map { FLText("row number \($0)") }

        await withTaskGroup(of: Void.self) { group in
            for node in nodes {
                group.addTask { _ = cache.layout(for: node, in: Self.context) }
            }
        }

        #expect(cache.count == nodes.count)
    }

    // MARK: - The platform calls a measurement makes

    /// Each side builds its own string from `Sendable` inputs rather than sharing one.
    ///
    /// That is not a convenience: `NSAttributedString` is not `Sendable`, so handing one to a detached
    /// task does not compile here — "sending value of non-Sendable type risks causing data races" — and
    /// that is the same constraint `FLText.attributedText` answers with `nonisolated(unsafe)`. Building
    /// each side separately is also the shape a cache probe actually takes, per `node-equality.md`: two
    /// independently built equal strings, where identity never matches.
    nonisolated private static func measureNarrow(_ text: String) -> CGRect {
        NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 13)])
            .boundingRect(
                with: CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
    }

    @Test("NSAttributedString.boundingRect returns the same rect off the main thread")
    func boundingRectAgreesAcrossThreads() async {
        let text = "a paragraph long enough to wrap across several lines when measured narrow"

        let offMain = await Task.detached { Self.measureNarrow(text) }.value
        let onMain = await MainActor.run { Self.measureNarrow(text) }

        #expect(offMain.height > 0)
        #expect(offMain == onMain)
    }

    @Test("the UIFont values FLText defaults to are the same off the main thread")
    func defaultFontAgreesAcrossThreads() async {
        let offMain = await Task.detached { (FLText.defaultFont, UIFont.labelFontSize) }.value
        let onMain = await MainActor.run { (FLText.defaultFont, UIFont.labelFontSize) }

        #expect(offMain.0 == onMain.0)
        #expect(offMain.1 == onMain.1)
    }
}
