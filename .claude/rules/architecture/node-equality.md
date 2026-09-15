# Node Equality Rules

How `FLNode`'s `Hashable` conformance is produced, and why it is never hand-written.

`FLNode: Hashable` is load-bearing: `FLLayoutCache` keys on `(node, context)`, so `==` decides whether
a cached layout is reused and `hash(into:)` decides which bucket it lands in.

## Let the compiler synthesise it

Do not write `==` or `hash(into:)` for a node. Synthesis is correct even when the node stores a
Foundation reference type — verified for `nonisolated(unsafe) let attributedText: NSAttributedString`,
where it produces exactly the behaviour a hand-written version does:

| | `==` | hash equal |
| --- | --- | --- |
| distinct instances, same content | true | true |
| same text, different attributes | false | true |
| different text | false | false |

Row 2 is a hash collision on unequal values, which `Hashable` permits — Foundation's
`NSAttributedString.hash` folds in the string but not the attributes. `==` still separates them, so a
cache lookup returns a miss, never a wrong hit. Attribute-only variants sharing a bucket is
acceptable; most styling in this system lives in `overrides`, which hashes separately.

What matters is that row 1 holds: `NSAttributedString.hash` is **content**-based, not identity-based.
A node built fresh from the same model must hash equal to the cached one or the cache never hits.

## Layout identity is a separate question from equality

`FLLayoutEquatable` asks whether two values produce the same **geometry**; `==` asks whether they are the
same value. Both exist, neither replaces the other, and `Hashable` stays synthesised exactly as above.

```
a == b                        ⟹  a.layout(in: c) == b.layout(in: c)
a.isLayoutEquivalent(to: b)   ⟹  a.layout(in: c) == b.layout(in: c)
```

The first holds because `layout(in:)` is a pure function of node and context, which is why the protocol's
default is `==` and every type satisfies the contract for nothing. Layout identity is the **coarser**
relation: the same classes, merged further. So over-narrowing is the only unsound direction, and the
mark is on the properties that are layout-*neutral* rather than a list of the ones that matter — an
omission from a list of what matters is a wrong hit, an omission from a list of what is neutral is a
missed merge.

Note the obligation is stated on the **layout**, not the size, and the difference is not academic — a
cache hands back the whole `Layout` and the renderer applies child frames out of it:

| type | agrees on `size`, differs in |
| --- | --- |
| `FLFrameLayout` | `wrappedFrame` — `.frame(width:height:alignment:)` at `.leading` against `.trailing` |
| `FLScrollLayout` | `contentSize` — one viewport, two contents |
| `FLStackLayout` | `childFrames` — alignment inside a stack wider than its children |

`layout-proposals.md` records the same trap one level up, as something this project actually hit: "outer
sizes agreed for a whole session while the rendering diverged, because a frame that crops a 160×320 child
and one that fits a 50×100 child both report 160×100". Stating the obligation on the size would write
that failure into the type system.

It also costs nothing to state the stronger version, since `FLLayout: Equatable` already. A contract test
must compare layouts for the same reason — one comparing sizes would pass while the design was broken.

**Narrowing is a standing obligation, not a one-time edit.** A hand-written `isLayoutEquivalent` names
the fields that matter *at the time it was written*, so adding a stored property to a narrowed type
silently omits it — and that omission is the wrong-hit direction. When you add a field to any type with a
conformance of its own, decide there and then whether measurement reads it. Which types carry one is a
question for the code, not for this file — `grep -rln 'func isLayoutEquivalent' Sources` lists them.

**A partial conformance is safe in both directions**, which is what makes the pair cheap to hand-write.
Narrow `isLayoutEquivalent` and forget `hashLayoutIdentity`, and the two values land in different buckets
— a miss. Narrow the hash and forget equality, and they share a bucket and `==` then rejects — also a
miss. Neither produces a wrong hit, so getting it half-right costs only the benefit.

`FLLayoutKey` hand-writes `==` and `hash(into:)` and is not an exception to the synthesis rule: it is not
a node, and delegating to layout identity is the entire reason it exists. Synthesis there would compare
its two fields as values, which is the behaviour it replaces.

## No `===` fast path

Do not guard a content comparison with an identity check:

```swift
// no
lhs.attributedText === rhs.attributedText || lhs.attributedText == rhs.attributedText
```

Foundation already short-circuits identical pointers inside `isEqual:`. The guard saves only the
Objective-C dispatch. Measured on a 90 000-character attributed string, `-O`:

| comparison | `==` alone | with the guard |
| --- | --- | --- |
| identical instance | ~10 ns | ~0 ns |
| independent instances, equal content | ~2 700 ns | ~2 700 ns |
| unequal, same length | ~2 500 ns | — |
| unequal, different length | ~30 ns | — |

~10 ns against a text measurement in the tens of microseconds, and nothing at all in the case that
actually costs. That case is also the normal shape of a cache probe after a model rebuild — two
independently built equal strings, where identity never matches and the guard is pure overhead.

Note the cost is driven by string *length*, so it is bounded by how long a message is, and a
length mismatch is rejected without reading content. `hash(into:)` on the same string is ~50 ns, so
bucketing is cheap and only the final confirming `==` walks content.

Reproduce with the `Benchmark: NSAttributedString equality` suite in
`Tests/FrameLayoutTests/Benchmarks/`, which carries the full table and both readings as documentation. It
lives in the test target so it runs on the simulator and is one click away, at the cost of a Debug
build inflating the numbers — set the test action to Release in the scheme when the absolute figures
matter. The suite asserts only on semantics, never on a timing.

Two traps when writing such a measurement, both of which leave the two sides sharing backing storage
and understate the cost by ~20×: `NSAttributedString(attributedString:)` copies share the backing
string, and `sharedBody + ""` hands back the original's storage. Allocate each side from scratch. Also
compare strings of *equal* length — otherwise the length check answers before any content is read.

## Existing hand-written conformances

`FLTuple`, `FLComposed`, `FLImage` and `FLAttributedString`, each for a reason that is not "the
synthesised one looked wrong":

- `FLTuple` and `FLComposed` — structural. A parameter pack and a stored existential body cannot be
  compared field-wise by synthesis.
- `FLAttributedString` — one of its two stored strings is **derived** from the other. Synthesis would
  compare `layoutIdentity` as well as `text`, walking a second string for an answer the first already
  gave, on a path that runs per cache probe.
- `FLImage` — deliberate. `UIImage.isEqual:` compares pixel data, which is unbounded work on a cache
  probe, and its `hash` semantics are unverified. It hashes `image?.size` instead: cheap,
  content-derived, and consistent with an `==` that accepts either identity or content equality.
  **Do not change this conformance without a `UIImage` benchmark alongside the string one** — the claim
  it rests on, that pixel comparison is unbounded work on a cache probe, is reasoned rather than
  measured. `Tests/FrameLayoutTests/Benchmarks/` is where that measurement goes.

Note this is the opposite conclusion from `FLText`, and for a concrete reason — `NSAttributedString`
comparison is bounded by message length and short-circuits on a length mismatch, `UIImage` comparison
is bounded by pixel count. Do not generalise either verdict to the next reference type; measure it.

## A hand-written dynamic `UIColor` must be one shared instance

`UIColor(dynamicProvider:)` wraps a closure, and nothing about two blocks tells `isEqual:` whether they
compute the same thing. So for a colour built that way `UIColor` falls back to instance equality:

| | `===` | `==` | hash |
| --- | --- | --- | --- |
| `.label`, two separate accesses | yes | yes | yes |
| two `UIColor(dynamicProvider:)`, identical closures | no | **no** | **no** |
| one `UIColor(dynamicProvider:)`, against itself | yes | yes | yes |
| two component colours, same components | — | yes | yes |
| `.label` vs `.label.resolvedColor(with:)` | — | no | — |

Pointer identity **does** short-circuit, so one shared instance is equal to itself and hashes stably.
That is the whole fix, and it is why a system colour is safe — `.label` is a cached singleton.

**The mistake is `static var`, and it is invisible at the call site.**

```swift
// no — a computed `static var` makes a new object on every access
extension UIColor {
    static var bubble: UIColor { UIColor { $0.userInterfaceStyle == .dark ? .dark : .light } }
}

// yes — one object, created once, shared by every reference
extension UIColor {
    static let bubble = UIColor { $0.userInterfaceStyle == .dark ? .dark : .light }
}
```

Both read as `.bubble` where they are used. The only symptom of the first is a layout cache that never
hits, with no diagnostic — which is why this is a written rule rather than a doc comment. Sharing an
instance costs no dynamic behaviour; UIKit still resolves it per trait collection at draw time.

### That is the whole rule, and it does not extend past a hand-written closure

Every other way of making a colour is stable however it is spelled, which is not what the `static var`
warning above suggests if it is read as being about dynamic colours in general:

| construction | `===` | `==` |
| --- | --- | --- |
| `UIColor(Color.red)` / `UIColor(Color.primary)`, two accesses | yes | yes |
| `UIColor(Color.primary.opacity(0.4))`, two accesses | yes | yes |
| `UIColor(aComputedVarReturningAColor)` | yes | yes |
| `UIColor(Color(red:green:blue:))`, two accesses | no | yes |
| `withAlphaComponent(_:)` on a system colour | no | yes |
| `withAlphaComponent(_:)` on one shared dynamic colour | no | yes |
| `UIColor(Color(uiColor:))` over **two fresh providers** | no | **no** |

Two conclusions a reader would otherwise draw from the `static var` rule, both wrong:

- **A SwiftUI-sourced token needs no UIKit-side ceremony.** SwiftUI caches the bridge, so `UIColor(Color)`
  comes back pointer-identical — `.primary` included, `.opacity(_:)` included, and from a *computed* `var`.
  A design system whose tokens are `Color`s is safe as it stands.
- **A derivation does not have to be stored.** Two separate `withAlphaComponent(_:)` calls off one base
  compare equal, dynamic base included, so a computed scrim is a stable key.

The last row is what keeps the rule pointed at the closure rather than at UIKit: laundering a fresh
provider through `Color(uiColor:)` does not launder the instability.

### Where a colour still reaches a cache key: one place

**Stored on whatever the cache is rooted on** — `let bubbleColour: UIColor` on a composite. A consumer's
composite does not hand-write `isLayoutEquivalent`, so it falls to the whole-value default in
`FLLayoutEquatable` and its synthesised `==` walks the colour.

Three places that used to be on this list are closed, and are recorded because the closure is what makes
the remaining one easy to check rather than because any of them is a live hazard:
`FLEnvironment.isLayoutEquivalent` excludes `foregroundColor`, `FLDecorated` hashes `wrapped` alone, and
`FLAttributedString` strips the four colour attributes from `layoutIdentity` at construction. **Store an
`FLAttributedString`** rather than a bare `NSAttributedString` for that last one to keep holding: `==`
still separates the two so a diff still sees a highlight change, while layout identity merges them.

A colour built inside a composite's `body` was never on the list, because `FLComposed.==` compares
`composite` alone.

### The cache miss is the cheap half

Reading `cgColor` on a **freshly built** provider colour costs milliseconds. Reading it on one that has
been read before costs ~400 ns, and on a resolved colour ~130 ns. The cost is per instance on its first
read, so a token rebuilt per access pays it on **every** access while a shared instance pays it once per
process — orders of magnitude more than the missed measurement the rule above is about.
`FLDecoratedView.update` reads `cgColor` twice per update.

**Do not quote those magnitudes or act on them yet.** They are measured in a test process with no window,
and neighbouring rows move by more than 10× between runs, so only the ordering is established. A hosted
measurement inside a real view update is the prerequisite for changing `FLDecoratedView` — and if it
confirms, the change is the one the next paragraph already prescribes.

Resolution belongs in `update` — `FLTextView.update` resolves through `context.environment` — and must
not be hoisted into node construction as an optimisation, because a resolved colour is a different
colour from its dynamic source and changes on every appearance change.

### The hazard is not this package's

A value used as an identity must be stable, and a closure cannot be compared. Anything that diffs on
equality pays for it: SwiftUI deciding whether to re-evaluate a body, a diffable data source deciding
whether a row changed, any `Dictionary` or `NSCache` keyed on a type storing the colour. `FLLayoutCache`
is one entry on that list rather than the subject. Imperative UIKit is the one place it is free —
`view.backgroundColor =` compares nothing — which is why the mistake sits in a codebase for years and
surfaces only when something starts caching.

Three suites in `Tests/FrameLayoutTests/` pin all of the above: `Runtime/FLColorIdentityTests` for the
equality table, `Runtime/FLColorProvenanceTests` for the provenance table and the SwiftUI half, and
`Benchmarks/FLColorCostBenchmarks` for the read costs. They assert a *platform* behaviour, which is
deliberate: the singleton identity of `.label` is load-bearing for hit rates across the package, and if
two separately built dynamic colours ever start comparing equal, this rule should be revisited rather
than left in place.

**An asset-catalogue colour is not covered** — `Color("Name")` / `UIColor(named:)` needs a colorset in
the test bundle. It is the most likely shape for a real design token, so the provenance table above must
not be read as covering one.

## A `UIFont` needs nothing — and that is a measurement, not an assumption

The same question asked of the other reference type in the key, with the opposite answer. `UIFont`
compares and hashes by **content**, so a font rebuilt per access is one cache key and a consumer has
nothing to do:

| | `===` | `==` | hash |
| --- | --- | --- | --- |
| `.systemFont(ofSize: 17)`, two accesses | yes | yes | yes |
| `.preferredFont(forTextStyle: .body)`, two accesses | yes | yes | yes |
| two `UIFont(descriptor:size:)` from equivalent descriptors | yes | yes | yes |
| `.systemFont(ofSize: 17)` vs `.systemFont(ofSize: 17, weight: .regular)` | **no** | yes | yes |
| `.systemFont(ofSize: 17)` vs `.systemFont(ofSize: 18)` | no | no | no |
| `.body` vs `.body` at `.extraLarge` | no | no | no |

The reason, which is what generalises: a font is fully described by its **descriptor**, which is
comparable data. A dynamic colour is described by a closure, which is not. Nothing about being a UIKit
reference type in a cache key decides the answer either way.

**Row 4 is the load-bearing one, and the trap in reading this table.** UIKit caches fonts, so every
"two accesses" row is pointer-identical and each of those `==` results is equally well explained by
identity alone — exactly as `.label`'s is. Only two *distinct* instances comparing equal proves the
relation is content-based, and it is that proof, not the caching, which makes the key safe if the font
cache ever misses. A table without such a row cannot tell the two situations apart; the first pass of
the colour probe had the same gap.

Note also why this cannot be dodged the way the colour case can. `foregroundColor` is layout-neutral and
leaves the key entirely; `font` affects measurement and stays in it at every root, through `FLContext`.
And the colour mitigation would not transfer — a theme colour is held as a `static let`, while a font is
normally built per call, so there would be nothing to share.

`FLFontIdentityTests` in `Tests/FrameLayoutTests/Runtime/` pins every row, including the cache
consequence, and passes identically on iOS 17.5 and 26.1 — the ends of the supported range. It asserts a
platform behaviour for the same reason the colour suite does: a font that stopped comparing by content
would cost every consumer their hit rate silently, and there would be no workaround to document.
## A `Layout` stores geometry only

Every `FLLayout` in the package stores `size`, child frames, `contentSize` or children, and nothing else.
Keep it that way, because it is the invariant that decides whether a layout-neutral mark is sound.

Anything non-geometric in a `Layout` is a **node property pinned into the cache key**. Excluding that
property from layout identity then serves a cached layout built from different inputs — a wrong hit,
where every other failure in this area is only a miss. With the invariant held, checking a new mark is
one file rather than an inventory: if the property does not reach `layout(in:)`, it cannot reach the
`Layout`, so excluding it cannot change what a cache returns.

`FLDecoratedLayout.cornerMask` was the one violation. It held a four-bit `CACornerMask` derived from
`FLDecoration.corners` and `FLContext.layoutDirection`, which made `corners` the single field of
`FLDecoration` reaching `layout(in:)`. It is gone: `FLDecoratedView.update` resolves the mask from
`FLRenderContext.environment.layoutDirection`.

**It would not have stayed local, either.** `FLStackLayout.children` is an `FLGroupChildren` storing
`layouts: [FLAnyLayout]`, so a decorated child's non-geometric field is part of the enclosing **stack's**
layout equality, and the grid's. A mark excluded at the node would have been unsound at every ancestor,
not only at the type that declared the field.

### A wrapper whose payload is applied at update has no `Layout` of its own

Such a node takes its child's:

```swift
public typealias Layout = Wrapped.Layout

public func layout(in context: FLContext) -> Wrapped.Layout {
    wrapped.layout(in: context)
}
```

A `Layout` that stores only `wrapped` and computes `size` through it carries no information, so it is a
type to delete rather than to maintain.

**Being spelled that way is not the test, and `FLEnvironmentOverride` is the counterexample** — it
already has `Layout == Wrapped.Layout` and is still layout-*affecting*, because it hands the child a
changed `FLContext`. Both halves are required: the layout passes through **and** the context passes
through unchanged. The second half is visible only in `layout(in:)`, so read it there rather than
inferring from the `typealias`.

## Never store a CoreGraphics aggregate on anything `Hashable`

`CGPoint`, `CGSize`, `CGRect`, `CGVector` and `CGAffineTransform` gained their `Hashable` conformances in
**iOS 18**. This package targets iOS 17. Synthesis over a stored one compiles with no diagnostic and
**traps at runtime** on the minimum:

```
Crash: xctest at lazy protocol witness table accessor for type CGSize and conformance CGSize
```

Store `FLPoint`, `FLSize` or `FLRect` instead, and expose the CoreGraphics spelling as an accessor if the
public API wants one — `FLScrollConfiguration.initialContentOffset` is the worked example. Delete all
three when the minimum reaches iOS 18.

**Waiting is the only way out: the minimum cannot go below 17.** Measured by dropping
`platforms: [.iOS(.v17)]` a version and building, which fails at exactly two sites, both `FLConcat`:

```
Sources/FrameLayout/Group/FLConcat.swift:5:24: error: parameter packs in generic types
are only available in iOS 17.0.0 or newer

public struct FLConcat<each Child: FLGroup>: FLGroup {
```

Variadic generics in a generic *type* need runtime metadata that shipped in iOS 17, and `FLConcat` is
produced by every multi-child builder, so it is not removable without fixed-arity overloads —
`FLTuple2`, `FLTuple3` and so on, the shape `TupleView` had before packs. Nothing else in the package
objected: `AttributedString` is iOS 15, and the concurrency annotations bind the toolchain rather than
the deployment target.

So the language forces 17 and 17 lacks these conformances. The three types are structural rather than a
preference, and the only thing that removes them is a decision to raise the floor to 18.

**The danger is exactly the five that conform *from* iOS 18.** A type that never conforms is safe
*because* it never conforms: synthesis over `UIEdgeInsets`, `UIOffset` or `NSDirectionalEdgeInsets` fails
outright with "does not conform", so the compiler stops it. The trap needs a conformance that exists when
the code is compiled and not when it runs. `FLEdgeInsets` exists because `UIEdgeInsets` is in the safe
row; `FLPoint` and friends exist because these five are not.

An explicit `hasher.combine(aCGSize)` **is** diagnosed. Only synthesis is silent, so the audit is "types
with a stored `CG*` property", not "every mention of one". A `Layout` may store them freely: `FLLayout`
refines `Equatable` only, and the `Equatable` conformances are not gated.

**Nothing in the package catches this except running on the floor.** `make test-minimum` exists for it,
and it is why `make test` runs both destinations. A suite green on the latest simulator says nothing
about iOS 17 — the whole suite was green there for months while crashing on the minimum.

## When a node cannot be synthesised

If a stored property is genuinely not `Hashable`, that is a signal about the property, not a reason to
hand-write the conformance. A node must stay a pure description — no closures, no view references, no
handlers — so anything blocking synthesis usually should not be stored on the node at all.
