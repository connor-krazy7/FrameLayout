# Absent Node Rules

What a node that stands for content which is not there contributes to its parent, and which nodes are
allowed to say they are one.

An `if` with no `else` that did not run is the only producer today: the builder hands back
`FLOptional(wrapped: nil)`. `FLNode.isAbsent` is how that fact travels, and it is answered **before
measuring** — `FLOptional` knows from its stored property, so `FLSingle` can decide `childCount` with
it, which a layout-time answer could not.

## A group drops an absent child; nothing else does

`FLSingle` answers `childCount` 0 and `FLGroupChildren.empty`, and that is the whole mechanism. Every
container already handles a group contributing no children — it is what `FLOptionalGroup` has always
done for an `if` written inline — so no stack, grid, spacing or view code takes part.

Two spellings of the same branch therefore agree, which they did not before `isAbsent` existed. In an
`FLVStack(spacing: 8)` between two 40pt swatches:

| spelling | before | after | SwiftUI |
| --- | --- | --- | --- |
| `if` inline in the stack builder | 88 | 88 | 88 |
| via a node property | 96 | 88 | 88 |
| via a node property, `.padding(10)` at the use site | 116 | 88 | 88 |

## A wrapper forwards; a view of its own does not

**This is the decision a new node has to make, and it is not a judgement call — it follows from whether
the node draws or arranges anything of its own.**

| the node | `isAbsent` | examples |
| --- | --- | --- |
| wraps one child and adds only geometry or configuration | `wrapped.isAbsent` | `FLPadded`, `FLFrame`, `FLAspectRatio`, `FLDecorated`, `FLBackground`, `FLOverlay`, `FLEnvironmentOverride`, `FLDisabled`, `FLTagged`, `FLAccessible`, `FLAnimated`, `FLAdjusted` |
| is a view in its own right | the default `false` | `FLScroll`, `FLButton` |
| holds a body that may itself be absent | `body.isAbsent` | `FLComposed` |

SwiftUI draws the line in the same place, and this was measured rather than reasoned:

| in a `VStack(spacing: 8)` | SwiftUI |
| --- | --- |
| absent, `.padding`, `.frame` over an absent child | 88 — no slot |
| `ScrollView { absent }` | 96 — keeps its slot |
| `Button { absent }` | 96 — keeps its slot |
| `Color.clear` at 0x0, a genuinely zero-sized child | 96 |

`FLScroll` and `FLButton` forwarded it in the first version of this work. A scroll view with nothing in
it is still a scroll view, and a button with no label is still a tap target the consumer asked for.

**Forwarding is a standing obligation on every new wrapper**, like `isSpacer` beside it. Forgetting
restores the child's slot in every container — a visible extra gap, never a wrong cache hit, so it
fails in the safe direction and will be noticed rather than silently corrupt a layout.

`isAbsent` is deliberately not on `FLLayout`. Keeping it off leaves `FLAnyLayout` as it was and the
geometry-only invariant in [node-equality.md](node-equality.md) intact, so nothing new reaches a cache
key; and a layout-time answer would arrive too late for `childCount`.

## Both readings of the same chain are correct

Because elision happens where a **group asks for children** rather than at the node, the same chain
measures differently on its own and inside a container, and neither number is wrong:

| `optionalView.padding(10)`, condition false | size |
| --- | --- |
| hosted alone | 20 x 20 — the insets resolve around nothing |
| inside any container | nothing, and no spacing |

SwiftUI reports exactly the same pair. A reader meeting the first number will think it is a bug; it is
the reason `FLSwiftUIParityTests.absentAtTheRootIsNotTheContainer` exists.

## Measuring it: a container, and non-zero spacing

Two ways to get a green suite that proves nothing, both hit while writing this rule:

- **`UIHostingController.sizeThatFits` cannot see a slot at all.** It measures the chain as a root,
  where the modifiers still resolve, so it reports 20 x 20 for something that occupies nothing wherever
  it is used. [layout-proposals.md](layout-proposals.md) records the placement half of this trap; the
  slot half is worse, because the number looks like a normal answer.
- **At spacing 0, a dropped child and a zero-sized child are indistinguishable.** Both give the same
  total, so a suite written that way passes with the elision entirely broken. One gap of 8 is what
  separates 88 from 96, and it is how `FLScroll` and `FLButton` were caught.

So: measure in a container, pass a spacing, and compare against the swatches alone.

## Reserving space is a different job

`absent.frame(width: 100, height: 100)` reserves nothing inside a container, and should not — SwiftUI
agrees. To hold a box for content that has not arrived, make the content **present and empty**:

```swift
FLColor(.clear).frame(width: 100, height: 100)
```

## What pins this

`FLConditionalTests` for the node path, the modifiers, an absent composite, and the view being taken
off screen; `FLSwiftUIParityTests` for every comparison against SwiftUI above, including the
`FLScroll` / `FLButton` boundary; `FLAbsentOptionalComparisonTests` for the demo that shows both
readings side by side.
