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

## Overflow is real, and it propagates

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

## Capping a ratio-driven image

`frame(maxHeight:)` cannot cap a `aspectRatio` image's height when no height is proposed — the image
answers from the width, and the bound only clips the box that is reserved for it. SwiftUI behaves the
same way, so this is not a gap to fix. Express the cap on the axis that is actually being proposed:

```swift
FLImage(image)
    .resizable()
    .aspectRatio(photo.ratio, contentMode: .fit)
    .frame(maxWidth: min(photo.pixelSize.width, Self.maximumHeight * photo.ratio))
```

`maximumHeight * ratio` is the width at which the height reaches the cap. `min` with the photo's own
width keeps a small image from being upscaled.

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
`.exact` path, which is why rows 3 and 4 of the table differ.

`print` from a test is not captured in `xcodebuild` output or in the result bundle. To get numbers out of
an exploratory test, accumulate them and fail on purpose — `Issue.record(Comment(rawValue: report))`
surfaces the string in the failure message.

## Consequences

- Text metrics differ from UIKit's by a fraction of a point, so parity assertions on anything containing
  `FLText` need a tolerance of about 1pt. Pure geometry matches exactly.
- A cell's width is almost always an exact proposal, so the `.exact` path is what production layout
  exercises. The `.unspecified` path is mostly the height axis — which is precisely where the bug lived
  and where new bounded-frame behaviour needs a test.
