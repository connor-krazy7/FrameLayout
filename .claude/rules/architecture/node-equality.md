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
conformance of its own, decide there and then whether measurement reads it. The types carrying one today
are `FLEnvironment`, `FLEnvironmentOverrides`, `FLScrollConfiguration`, `FLColor`, `FLImage`, `FLText`,
`FLScroll`, `FLEnvironmentOverride`, `FLComposed`, `FLContext`, and the seven pass-through wrappers.

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

## A dynamic `UIColor` must be one shared instance

`UIColor(dynamicProvider:)` wraps a closure, and nothing about two blocks tells `isEqual:` whether they
compute the same thing. So for dynamic colours `UIColor` falls back to instance equality:

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

Four places a colour reaches a cache key, and note which one is absent: a colour built inside a
composite's `body` is not among them, because `FLComposed.==` compares `composite` alone.

1. Stored on whatever the cache is rooted on — `let bubbleColour: UIColor` on a composite.
2. In `FLEnvironment.foregroundColor`, which is in the key at **every** root via `FLContext`.
3. A chain-rooted cache, where `FLDecoration` is hashed directly.
4. Inside a stored `NSAttributedString`, since attribute comparison is part of its equality. **Store an
   `FLAttributedString` instead** — it strips the attributes that change no glyph advance once at
   construction, so a colour in a run costs nothing, while `==` still separates the two so a diff still
   sees the highlight. `FLText` stores one; a composite holding attributed text of its own should too.

Resolution belongs in `update` — `FLTextView.update` resolves through `context.environment` — and must
not be hoisted into node construction as an optimisation, because a resolved colour is a different
colour from its dynamic source and changes on every appearance change.

`FLColorIdentityTests` in `Tests/FrameLayoutTests/Runtime/` pins every row above, including the cache
consequence. It asserts a *platform* behaviour, which is deliberate: the singleton identity of `.label`
is load-bearing for hit rates across the package, and if two separately built dynamic colours ever
start comparing equal, this rule should be revisited rather than left in place.

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

## When a node cannot be synthesised

If a stored property is genuinely not `Hashable`, that is a signal about the property, not a reason to
hand-write the conformance. A node must stay a pure description — no closures, no view references, no
handlers — so anything blocking synthesis usually should not be stored on the node at all.
