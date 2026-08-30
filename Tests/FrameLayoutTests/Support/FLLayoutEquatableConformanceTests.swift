import Testing
import UIKit

@testable import FrameLayout

@Suite("Standard-type layout identity")
struct FLLayoutEquatableConformanceTests {
    private static func identityHash(of value: some FLLayoutEquatable) -> Int {
        var hasher = Hasher()
        value.hashLayoutIdentity(into: &hasher)

        return hasher.finalize()
    }

    @Test("a scalar follows its own equality")
    func scalarsFollowEquality() {
        #expect("a".isLayoutEquivalent(to: "a"))
        #expect("a".isLayoutEquivalent(to: "b") == false)
        #expect(Self.identityHash(of: 7) == Self.identityHash(of: 7))
        #expect(CGFloat(1.5).isLayoutEquivalent(to: 1.5))
    }

    @Test("a container recurses into its elements")
    func containersRecurse() {
        #expect([1, 2].isLayoutEquivalent(to: [1, 2]))
        #expect([1, 2].isLayoutEquivalent(to: [2, 1]) == false)
        let absent: String? = nil
        let present: String? = "a"

        #expect(absent.isLayoutEquivalent(to: absent))
        #expect(present.isLayoutEquivalent(to: absent) == false)
        #expect(["k": 1].isLayoutEquivalent(to: ["k": 1]))
    }

    // The one knowingly coarse conformance, and the reason it is worth a test: the same visual change is
    // The raw Foundation types take the default, so a colour in a run still separates them. Wrapping
    // in `FLAttributedString` is what narrows it; this is the contrast.
    @Test("a raw attributed string keeps colour in its layout identity, the wrapper does not")
    func attributedColourNarrowsOnlyThroughTheWrapper() {
        let plain = NSAttributedString(string: "highlighted")
        let coloured = NSAttributedString(
            string: "highlighted",
            attributes: [.foregroundColor: UIColor.systemYellow]
        )

        #expect(plain.isLayoutEquivalent(to: coloured) == false, "raw: coarse")
        #expect(
            FLAttributedString(plain).isLayoutEquivalent(to: FLAttributedString(coloured)),
            "wrapped: narrowed"
        )
        #expect(
            FLAttributedString(plain) != FLAttributedString(coloured),
            "but still unequal, so a diff still sees the highlight"
        )
    }

    // `CGPoint`, `CGSize` and `CGRect` are absent because their `Hashable` conformances are iOS 18+ and
    // `FLLayoutEquatable` refines `Hashable` — see #11. Asserted through `FLImage`, whose own narrowing
    // hashes the components rather than the aggregate for the same reason.
    @Test("a size reaches layout identity through its components")
    func sizesReachIdentityByComponent() {
        let image = UIImage(systemName: "star")

        #expect(FLImage(image).isLayoutEquivalent(to: FLImage(image)))
        #expect(Self.identityHash(of: FLImage(image)) == Self.identityHash(of: FLImage(image)))
    }
}
