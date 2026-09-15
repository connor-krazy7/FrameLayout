import SwiftUI
import Testing
import UIKit
@testable import FrameLayout

/// Which *ways of making* a `UIColor` produce a stable identity, which is what decides whether a
/// consumer's type storing one is safe under synthesised `==` and `hash`.
///
/// [node-equality.md](../../../.claude/rules/architecture/node-equality.md) establishes that a
/// `UIColor(dynamicProvider:)` falls back to instance equality, and `FLColorIdentityTests` pins that.
/// This suite asks the question one step earlier — not "are two dynamic colours equal" but "does this
/// construction hand back the same instance twice" — because that is the question a consumer is
/// actually deciding when they write a colour token.
///
/// | construction | `===` | `==` | hash |
/// | --- | --- | --- | --- |
/// | `UIColor.label`, two accesses | yes | yes | yes |
/// | `UIColor(red:green:blue:alpha:)`, same components | no | yes | yes |
/// | `UIColor(dynamicProvider:)`, two fresh | **no** | **no** | **no** |
/// | `withAlphaComponent` on a system colour | no | yes | yes |
/// | `withAlphaComponent` on one shared dynamic colour | no | yes | yes |
/// | `UIColor(Color.red)`, two accesses | yes | yes | yes |
/// | `UIColor(Color.primary)`, two accesses | yes | yes | yes |
/// | `UIColor(Color.primary.opacity(0.4))`, two accesses | yes | yes | yes |
/// | `UIColor(computedVarReturningAColor)` | yes | yes | yes |
/// | `UIColor(Color(red:green:blue:))`, two accesses | no | yes | yes |
/// | `UIColor(Color(uiColor:))` over two fresh dynamics | **no** | **no** | **no** |
/// | `UIColor(Color(uiColor:))` over one shared dynamic | yes | yes | yes |
///
/// **Only one construction is unstable: a `UIColor(dynamicProvider:)` built fresh per access.** It
/// stays unstable when laundered through `Color(uiColor:)`, and everything else on the list is safe
/// however it is spelled.
///
/// Two rows are worth reading twice, because both contradict a plausible generalisation of the
/// `static var` rule in `node-equality.md`:
///
/// - **`UIColor(Color)` is pointer-stable**, `.primary` and `.opacity(_:)` included, and even from a
///   *computed* `var`. SwiftUI caches the bridge, so a design system whose tokens are SwiftUI `Color`s
///   does not need a `static let` on the UIKit side to keep a layout cache hitting.
/// - **`withAlphaComponent` compares equal across two separate derivations**, including off a dynamic
///   base. A derived scrim does not have to be stored to be a stable key.
///
/// **The hazard is not this package's, and not UIKit's.** It is that a value used as an *identity* must
/// be stable, and a closure cannot be compared. Anything that diffs on equality pays for it: SwiftUI
/// deciding whether to re-evaluate a body, a diffable data source deciding whether a row changed, any
/// `Dictionary` or `NSCache` keyed on a type storing the colour. `FLLayoutCache` is one instance of that
/// list rather than the subject. Imperative UIKit is the one place it is free — `view.backgroundColor =`
/// compares nothing — which is why the mistake can sit in a codebase for years and surface only when
/// something starts caching. `swiftUIColorInheritsInstability` below pins the SwiftUI half.
///
/// This asserts **platform** behaviour, which the sibling colour and font suites also do and for the
/// same reason: each row is load-bearing for a consumer's cache hit rate, there is no diagnostic when
/// one changes, and the mitigation differs per row. A row flipping should fail here rather than show up
/// as an app that got slower.
///
/// **What this suite does not cover: an asset-catalogue colour** — `Color("Name")` or
/// `UIColor(named:)` — which needs a colorset in the test bundle. That is the most likely shape for a
/// real design token, so the table above should not be read as covering one.
@Suite("Colour provenance")
struct FLColorProvenanceTests {
    private static let sharedDynamic = UIColor { $0.userInterfaceStyle == .dark ? .white : .black }

    private static var computedToken: Color { Color.primary.opacity(0.4) }

    private static func freshDynamic() -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
    }

    @Test("a component colour compares by content, without being one instance")
    func componentColoursAreContentBased() {
        let first = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        let second = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)

        #expect(first !== second)
        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    @Test("a provider closure built fresh per access is the one unstable construction")
    func freshProviderClosuresDiffer() {
        let first = Self.freshDynamic()
        let second = Self.freshDynamic()

        #expect(first !== second)
        #expect(first != second)
        #expect(first.hashValue != second.hashValue)
    }

    // The generalisation that does not hold: a derived colour need not be stored to be stable, because
    // the derivation compares by its base and its alpha rather than by instance.
    @Test("withAlphaComponent compares equal across two derivations")
    func alphaDerivationsCompareEqual() {
        #expect(UIColor.label.withAlphaComponent(0.4) == UIColor.label.withAlphaComponent(0.4))
        #expect(
            Self.sharedDynamic.withAlphaComponent(0.4) == Self.sharedDynamic.withAlphaComponent(0.4)
        )
        #expect(
            Self.sharedDynamic.withAlphaComponent(0.4).hashValue
                == Self.sharedDynamic.withAlphaComponent(0.4).hashValue
        )
    }

    // The row that matters most to a consumer migrating a SwiftUI design system, and the one this suite
    // was written to settle: the bridge is cached, so no UIKit-side ceremony is needed to keep it stable.
    @Test("UIColor(Color) hands back one instance, dynamic and derived alike")
    func swiftUIBridgeIsCached() {
        #expect(UIColor(Color.red) === UIColor(Color.red))
        #expect(UIColor(Color.primary) === UIColor(Color.primary))
        #expect(UIColor(Color.primary.opacity(0.4)) === UIColor(Color.primary.opacity(0.4)))
        #expect(UIColor(Color(uiColor: .label)) === UIColor(Color(uiColor: .label)))
        #expect(UIColor(Self.computedToken) === UIColor(Self.computedToken))
    }

    @Test("a Color built from components is not one instance, but still compares by content")
    func swiftUIComponentColoursAreContentBased() {
        let first = UIColor(Color(red: 0.2, green: 0.4, blue: 0.6))
        let second = UIColor(Color(red: 0.2, green: 0.4, blue: 0.6))

        #expect(first !== second)
        #expect(first == second)
    }

    // Laundering through SwiftUI does not launder the instability, which is what makes the rule about
    // provider closures a rule about the closure rather than about UIKit.
    @Test("the bridge preserves whatever stability the source had")
    func bridgeInheritsSourceStability() {
        #expect(UIColor(Color(uiColor: Self.freshDynamic())) != UIColor(Color(uiColor: Self.freshDynamic())))
        #expect(
            UIColor(Color(uiColor: Self.sharedDynamic)) === UIColor(Color(uiColor: Self.sharedDynamic))
        )
    }

    // Nothing here is specific to this package. SwiftUI diffs view values to decide whether to
    // re-evaluate a body, so an unstable colour is an unstable `Color`, and the same mistake costs a
    // consumer who never imports FrameLayout.
    @Test("SwiftUI's own Color equality inherits the instability")
    func swiftUIColorInheritsInstability() {
        #expect(Color(uiColor: Self.sharedDynamic) == Color(uiColor: Self.sharedDynamic))
        #expect(Color(uiColor: Self.freshDynamic()) != Color(uiColor: Self.freshDynamic()))
    }

    // The consequence, measured through the cache rather than inferred from `==`. It has to be rooted on
    // a composite that stores the colour: `FLColor`'s own colour is layout-neutral.
    @Test("a composite storing a SwiftUI-sourced colour hits the cache")
    func swiftUISourcedColoursHit() {
        let context = FLContext(width: 100, height: 40)
        let cache = FLLayoutCache<FLComposed<ProvenanceSwatch>>()

        _ = cache.layout(for: ProvenanceSwatch(colour: UIColor(Color.primary)).node, in: context)
        _ = cache.layout(for: ProvenanceSwatch(colour: UIColor(Color.primary)).node, in: context)

        #expect(cache.count == 1)
    }
}

private struct ProvenanceSwatch: FLView {
    let colour: UIColor

    var body: some FLNode {
        FLColor(colour).frame(width: 100, height: 40)
    }
}
