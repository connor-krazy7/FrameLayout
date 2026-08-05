import Foundation
import Testing

@testable import FrameLayout

/// What an `NSAttributedString` comparison costs, which is what decides whether `FLText`'s `==` needs
/// an identity fast path ahead of the content comparison:
///
/// ```swift
/// lhs.attributedText === rhs.attributedText || lhs.attributedText == rhs.attributedText
/// ```
///
/// It does not. Measured on a 90 000-character attributed string, host arm64, `swiftc -O`:
///
/// | comparison                           | `==` alone | with the identity guard |
/// | ------------------------------------ | ---------- | ----------------------- |
/// | identical instance                   | ~10 ns     | ~0 ns                   |
/// | independent instances, equal content | ~2 700 ns  | ~2 700 ns               |
/// | unequal, same length                 | ~2 500 ns  | —                       |
/// | unequal, different length             | ~30 ns     | —                       |
/// | `hash(into:)`, for comparison        | ~50 ns     | —                       |
///
/// Two readings follow. Foundation already short-circuits identical pointers inside `isEqual:`, so the
/// guard saves ~10 ns of Objective-C dispatch rather than a content walk. And it saves nothing in the
/// case that actually costs — two independently built equal strings, which is the normal shape of a
/// cache probe after a model rebuild, where identity never matches. So `FLText` relies on synthesised
/// `Hashable`; see `.claude/rules/architecture/node-equality.md`.
///
/// Cost scales with string length and a length mismatch is rejected without reading content, so the
/// worst case is bounded by how long a message is. Hashing is ~50× cheaper than the confirming
/// comparison, so cache bucketing stays cheap.
///
/// The absolute figures above come from an optimised host binary. Run under a Debug test build these
/// inflate; the ordering is the finding, not the nanoseconds.
@Suite("Benchmark: NSAttributedString equality", .serialized)
struct NSAttributedStringEqualityBenchmarks {
    /// Each call allocates its own backing string, which is the whole point. Two shortcuts look
    /// equivalent and are not, because both leave the two sides sharing storage — Foundation then
    /// short-circuits and the measurement understates the real cost by ~20×:
    ///
    /// - `NSAttributedString(attributedString:)`, whose copy shares the backing string.
    /// - Concatenating onto a shared `let body`, where `body + ""` hands back `body`'s own storage.
    private static func build(replacingLastCharacterWith replacement: Character? = nil) -> NSAttributedString {
        let body = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 2000)
        let string = replacement.map { String(body.dropLast()) + String($0) }.or(body)

        return NSAttributedString(string: string, attributes: [NSAttributedString.Key("k"): "v"])
    }

    @Test("comparison cost by kind of difference")
    func equalityCost() {
        let subject = Self.build()
        let independentEqual = Self.build()
        // Differing in the last character only. Appending instead would let Foundation reject on
        // length without comparing any content, which measures nothing.
        let unequalSameLength = Self.build(replacingLastCharacterWith: "z")
        let unequalShorter = NSAttributedString(string: "The quick brown fox. ")

        #expect(Self.build() !== Self.build())
        #expect(subject == independentEqual)
        #expect(subject != unequalSameLength)
        #expect(subject.length == unequalSameLength.length)

        FLBenchmark.printConfiguration("equality, \(subject.length) characters:")
        let identical = FLBenchmark.measure("identical instance") { subject == subject }
        let equalContent = FLBenchmark.measure("independent instances, equal content") {
            subject == independentEqual
        }
        FLBenchmark.measure("unequal, same length") { subject == unequalSameLength }
        FLBenchmark.measure("unequal, different length") { subject == unequalShorter }

        // The finding worth defending: Foundation short-circuits on identity, so an identical-instance
        // comparison does not walk content. Bounded loosely — this pins the behaviour, not a timing.
        #expect(identical < equalContent / 2)
    }

    @Test("an identity guard ahead of the comparison buys nothing worth having")
    func identityGuardCost() {
        let subject = Self.build()
        let independentEqual = Self.build()

        FLBenchmark.printConfiguration("with an identity guard:")
        FLBenchmark.measure("identical instance") { subject === subject || subject == subject }
        FLBenchmark.measure("independent instances, equal content") {
            subject === independentEqual || subject == independentEqual
        }
    }

    @Test("hashing is far cheaper than the confirming comparison")
    func hashingCost() {
        let subject = Self.build()

        FLBenchmark.printConfiguration("hashing:")
        let hashing = FLBenchmark.measure("hash(into:)") {
            var hasher = Hasher()
            hasher.combine(subject)
            return hasher.finalize() == 0
        }
        let comparison = FLBenchmark.measure("== against independent equal content") {
            subject == Self.build()
        }

        #expect(hashing < comparison)
    }

    /// `NSAttributedString.hash` folds in the string but not the attributes, so same-text/different-
    /// attribute nodes collide in a bucket while `==` still separates them. Legal, and the reason
    /// synthesised `Hashable` is safe for `FLText` — a collision costs a miss, never a wrong hit.
    @Test("hashing is content-based, and ignores attributes")
    func hashingSemantics() {
        let plain = NSAttributedString(string: "Hello")
        let distinctButEqual = NSAttributedString(string: "Hello")
        let styled = NSAttributedString(string: "Hello", attributes: [NSAttributedString.Key("k"): "v"])

        #expect(plain !== distinctButEqual)
        #expect(plain == distinctButEqual)
        #expect(plain.hashValue == distinctButEqual.hashValue)

        #expect(plain != styled)
        #expect(plain.hashValue == styled.hashValue)
    }
}
