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

`FLTuple`, `FLComposed` and `FLImage`, each for a reason that is not "the synthesised one looked
wrong":

- `FLTuple` and `FLComposed` — structural. A parameter pack and a stored existential body cannot be
  compared field-wise by synthesis.
- `FLImage` — deliberate. `UIImage.isEqual:` compares pixel data, which is unbounded work on a cache
  probe, and its `hash` semantics are unverified. It hashes `image?.size` instead: cheap,
  content-derived, and consistent with an `==` that accepts either identity or content equality.
  Settling it needs a `UIImage` benchmark alongside the string one — the suites run on the simulator,
  so that is now possible where the earlier standalone script could not have done it.

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
4. Inside a stored `NSAttributedString`, since attribute comparison is part of its equality.

Resolution belongs in `update` — `FLTextView.update` resolves through `context.environment` — and must
not be hoisted into node construction as an optimisation, because a resolved colour is a different
colour from its dynamic source and changes on every appearance change.

`FLColorIdentityTests` in `Tests/FrameLayoutTests/Runtime/` pins every row above, including the cache
consequence. It asserts a *platform* behaviour, which is deliberate: the singleton identity of `.label`
is load-bearing for hit rates across the package, and if two separately built dynamic colours ever
start comparing equal, this rule should be revisited rather than left in place.

## When a node cannot be synthesised

If a stored property is genuinely not `Hashable`, that is a signal about the property, not a reason to
hand-write the conformance. A node must stay a pure description — no closures, no view references, no
handlers — so anything blocking synthesis usually should not be stored on the node at all.
