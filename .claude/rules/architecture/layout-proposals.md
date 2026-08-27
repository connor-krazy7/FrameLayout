# Layout Proposal Rules

What an `FLProposal` means to the child that receives it, and what a parent may do with the answer.

A proposal is a **question**, not a constraint: *"how big would you be at this size?"* A child may answer
with anything, including a size larger than what was proposed. The parent then reports its own size,
which is usually derived from that answer. Both halves matter — a node that clamps the answer to the
proposal, or that treats a bound as an answer, breaks composition in ways that only show up several
levels up.

## Only a pinned frame may hand a size down

`minWidth`/`maxWidth`/`minHeight`/`maxHeight` bound the **answer**. They are not sizes to propose.

```swift
private static func childProposal(
    _ proposal: FLProposal,
    min lower: CGFloat?,
    max upper: CGFloat?
) -> FLProposal {
    switch proposal {
    case let .exact(value):
        .exact(clamp(value, min: lower, max: upper))
    case .unspecified:
        pinned(min: lower, max: upper).map { FLProposal.exact($0) }.or(.unspecified)
    case .minimum, .maximum:
        proposal
    }
}
```

`pinned` returns a value only when `lower == upper` — that is, when the frame came from
`frame(width:height:)` and genuinely has one size to give. A bounded frame forwards `.unspecified`
unchanged and clamps whatever comes back.

The earlier version proposed the bound itself when nothing was proposed from above:

```swift
case .unspecified:
    finite(upper).or(lower).map { .exact(clamp($0, min: lower, max: upper)) }.or(.unspecified)
```

Two bugs came out of that one line. A flexible leaf inflated to its bound — `FLColor.frame(maxHeight: 140)`
reported 140 where SwiftUI reports 10. And `aspectRatio(_:contentMode: .fill)` received an exact height,
picked the height-limited scale, and returned a size **wider than the box**, so a photo capped with
`.frame(maxHeight:)` spilled out of the cell. Neither is visible in the modifier that causes it; both
surface as a parent that is mysteriously too wide.

## Never clamp a child's answer to what you proposed

A child that answers larger than proposed is not clipped by its parent, and the parent's own reported
size grows to match. Measured against SwiftUI at a 160pt-wide box, 16:9 image:

| chain | SwiftUI | FL |
| --- | --- | --- |
| `.fill` + `frame(height: 140)` | 249 × 140 | 249 × 140 |
| that, inside a `VStack` with a label | 249 × 154.7 | 249 × 155 |
| `.fill` + `frame(maxHeight: 140)`, no height proposed | 160 × 90 | 160 × 90 |
| `.fill` + `frame(maxHeight: 140)`, height proposed 1000 | 249 × 140 | 249 × 140 |
| `frame(maxHeight: 140)` on a flexible leaf | 160 × 10 | 160 × <140 |

Row 1 versus row 3 is the whole rule: an **exact** height supplies something for `.fill` to overflow
with, a **bounded** one does not. Row 4 shows the bound doing its actual job — clamping a height that
was proposed. Row 5 is the one place FL deliberately differs: it has no equivalent of SwiftUI's 10×10
default for a shape, so the parity test asserts "not inflated to the bound" rather than an exact match.

## A bounded frame hands its resolved box to the child

Bounding an axis resolves the frame's own size, and the child then lays out **in that box** rather than in
whatever it answered while being measured. `FLFrame` measures twice for this: once against the incoming
proposal, then again at `.exact(resolvedSize)` on any bounded axis whose bound actually clamped something.
The reported size still comes from the first pass — SwiftUI reports 160 wide for a `maxHeight`-bounded fit
image while placing a 50-wide child inside it, and FL matches.

Without the second pass a bound could only ever *crop* an oversized child. With it, `frame(maxHeight: 100)`
genuinely fits a ratio-driven image, which is what a reader expects it to mean.

Two properties keep it safe: the pass is skipped whenever it would ask the same question (every unbounded
axis, every bound that did not clamp), and it never iterates. `.fill` deliberately answers larger than any
proposal, so re-proposing to it returns the same oversized answer — a fixed-point loop would never
converge, and a deliberate `aspectRatio(.fill)` + `clipped()` crop still works.

**Reach for the `aspectRatio` cap overloads over a bare `frame(maxHeight:)` inside deep trees.** A
clamping frame roughly doubles in cost and nesting them compounds, while the cap overloads are shaped so
the bound never clamps and the second pass never fires.

What it costs, Debug `-Onone`, so read the ratios and not the absolute numbers:

| case | before | after |
| --- | --- | --- |
| bounded frame, bound clamps | 966 ns | 1 790 ns |
| bounded frame, bound does not clamp | 964 ns | 1 012 ns |
| unbounded frame | 524 ns | 523 ns |
| three clamping frames inside a clamped stack | 12 518 ns | 45 373 ns |
| the nested demo conversation row | 1 356 µs | 1 322 µs |

Four stacked clamps cost 3.6×. Realistic content is unaffected, because a frame only pays when its
bound actually bites.

## Reserving a box that hugs a ratio-driven image

`frame(maxHeight:)` fits the image, but the reserved box keeps the full proposed width — the bound acts on
the height, so nothing narrows the box to the photo. When the box itself should hug the content, express
the cap on the width:

```swift
FLImage(image)
    .resizable()
    .aspectRatio(photo.ratio, contentMode: .fit)
    .frame(maxWidth: min(photo.pixelSize.width, Self.maximumHeight * photo.ratio))
```

`maximumHeight * ratio` is the width at which the height reaches the cap. `min` with the photo's own
width keeps a small image from being upscaled. `aspectRatio(_:contentMode:boundedBy:)` packages exactly
this, and as a bonus the bound never clamps, so the placement pass is skipped.

All three cap overloads — `maxWidth:`, `maxHeight:`, `boundedBy:` — bound **both** axes, deriving whichever
limit they were not given, and every one routes through `boundedBy:`. The ratio ties the axes together, so
a single cap is enough information to bound the other, and the three spellings reserve the same box:

```swift
aspectRatio(0.5, contentMode: mode, maxWidth: 50)
aspectRatio(0.5, contentMode: mode, maxHeight: 100)
aspectRatio(0.5, contentMode: mode, boundedBy: CGSize(width: 50, height: 900))
```

That is a stronger promise than the bare `frame(maxWidth:)` / `frame(maxHeight:)` spellings make, and it
exists for `.fill`: a single cap leaves the derived axis unbounded, so `.fill` — which answers larger than
any proposal — would reserve 50 × 300, a box that is not the shape it claims. Use the bare frame spelling
when SwiftUI's behaviour is what is wanted; it stays available and is covered by its own parity test.

`boundedBy:` takes a `CGSize` rather than two maxima because a ratio-shaped box cannot honour two limits
independently: the tighter dimension decides, and separate `maxWidth`/`maxHeight` parameters read as a
promise about each axis that neither of them makes.

`min(W, H·r)` and `min(H, W/r)` cannot disagree about which dimension binds — `W ≤ H·r` and `W/r ≤ H` are
the same inequality — so the derived pair is always exactly ratio-shaped. The **box** is ratio-shaped only
when the limits are what bind: a finite proposal tighter than the derived limit still wins on that axis,
per the bounded-axis rule above, and then the box takes the proposal while the child stays ratio-shaped
inside it. In a cell that never happens on the height axis, because no height is proposed.

## Verifying against SwiftUI

Do not reason about parity from the documentation — measure it. `UIHostingController.sizeThatFits(in:)`
returns the size SwiftUI resolves for a proposal and **does not** clamp to it, so an overflowing subtree
appears as a size larger than the box. Prove that in the same run before trusting a comparison:

```swift
let control = UIHostingController(rootView: Color.red.frame(width: 300, height: 100))
    .sizeThatFits(in: CGSize(width: 160, height: .infinity))
```

If that returns 300 wide, oversizes are coming through and the numbers mean something. `FLSwiftUIParityTests`
holds the comparisons; add to it rather than writing a throwaway probe.

An infinite proposed height stands in for `.unspecified`. A finite one is a real proposal and takes the
`.exact` path, which is why rows 3 and 4 of the table differ. In a preview, pin the SwiftUI column with
`.fixedSize(horizontal: false, vertical: true)` or it inherits a finite height proposal from the enclosing
scroll view and answers a different question than the FL column beside it.

**`sizeThatFits` says nothing about where the child landed.** Outer sizes agreed for a whole session while
the rendering diverged, because a frame that crops a 160×320 child and one that fits a 50×100 child both
report 160×100. For any claim about placement, render and measure the drawn pixels — `FLSwiftUIParityTests`
does it with `ImageRenderer` and a bounding-box scan.

To get numbers out of an exploratory test, use the `Issue.record` rule in
[../testing.md](../testing.md) — `print` reaches neither the log nor the result bundle.

## Give a parity assertion containing `FLText` a 1pt tolerance

Text metrics differ from UIKit's by a fraction of a point. Pure geometry matches exactly, so assert
that exactly and reserve the tolerance for text.

**Put a new bounded-frame test on the height axis.** A cell's width is almost always an exact proposal,
so the `.exact` path is what production layout already exercises; the `.unspecified` path is mostly the
height axis, which is where the bug this rule exists for lived.
