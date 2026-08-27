# Leaf View Rules

How to back an `FLNode` with a `UIView`.

## Wrap UIKit controls, don't subclass them

An `FLNodeView` should subclass plain `UIView`. When a leaf needs UIKit behaviour, hold the control as
a subview and size it in `layoutSubviews`:

```swift
final class FLImageView: UIView, FLNodeView {
    private let imageView = UIImageView()

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }
}
```

Configure the inner control in `update(node:layout:)`, and keep the outer view's own state to layout
concerns such as `clipsToBounds`. The cost is one extra view per wrapped control, which is acceptable
and consistent with every other leaf.

### Apply the test: does the leaf need a hand-written `init()`?

**If it does, wrap instead of subclassing.**

`FLNodeView` requires `init()`, and wrappers reach it generically as `Wrapped.View()`. A plain `UIView`
subclass inherits `init()` and needs nothing. A subclass only has to write one when its UIKit
superclass declares its own designated initialisers — `UIImageView.init(image:)` does, `UILabel` does
not. That missing inheritance is the signal.

`FLImageView` subclassing `UIImageView` produced `EXC_BAD_ACCESS` as soon as it was wrapped
(`FLImage(…).background(…)`). Making the initialiser designated rather than convenience did **not**
help; only dropping the subclass did.

`FLTextView` subclasses `UILabel` and is fine by this test — `UILabel` declares no designated
initialiser, so `init()` is inherited and nothing had to be written.

### Suspect the initialiser when a leaf faults with an address that looks like a size

Do not reach for the compiler to catch this one.

`swiftc -typecheck` and `-emit-object -O` were both clean the whole time — it is a runtime memory
fault, not a compile error. The crash report from the preview shell had no backtrace at all; the only
usable signal was the faulting address `0x4073C00000000000`, which decodes as the `Double` `316.0` —
a `CGFloat` where a pointer was expected. If a leaf faults with an address that looks like a size,
suspect the view's initialiser before anything else.

## Pick the base class by whether the view draws

Two answers, and the choice decides whether the view eats touches:

| the view | base class | touches |
| --- | --- | --- |
| positions or configures children only | `FLStructuralView` | passes through unless a descendant claims them |
| draws content of its own | `UIView` (or a wrapped control) | keeps them |

Almost every view in the package is structural; the ones that draw are the three leaves `FLColor`,
`FLImage` and `FLText`, plus `FLScroll` and `FLRepresentableNode`, which wrap a control. Read the
current split off the code — `grep -rl ': FLStructuralView' Sources` — rather than from a list here, which
goes stale every time a modifier is added. This mirrors SwiftUI, where a layout container is not a view
at all but `Color` and `.background` are tappable where they draw.

**A new node's view defaults to `FLStructuralView` unless it draws.** Getting this wrong is invisible
until some unrelated screen finds a button that will not tap.

`FLDecoratedView` decides per update, because the same node covers both cases:

```swift
drawsContent = decoration.backgroundColor.cgColor.alpha > 0 || decoration.borderWidth > 0
```

## Delegate to `super.hitTest` and disclaim the result — never test subview frames

`FLStructuralView` asks UIKit, then declines to be the answer:

```swift
let hitView = super.hitTest(point, with: event)
guard hitView === self, !drawsContent else { return hitView }
return nil
```

Iterating direct subviews and testing frame containment looks equivalent and is not. It cannot answer
*"does anything inside this subview actually want the touch"* — and a wrapper's subview is usually
another wrapper (padding inside frame inside stack), so containment hands the touch one level down and
it is still swallowed, just deeper. Returning `nil` is what makes UIKit resume scanning **siblings**,
which is what lets transparency compose through a whole tower of wrappers. Delegating also inherits
`isHidden`, `alpha < 0.01`, `isUserInteractionEnabled`, clipping, and any child's own `hitTest`
override for nothing.

Two related mechanisms that are *not* this:

- `allowsHitTesting(false)` sets `isUserInteractionEnabled = false`, which blocks the whole subtree on
  purpose. That is the SwiftUI semantic — an inner `allowsHitTesting(true)` cannot re-enable it.
- `FLSpacerView` sets `isUserInteractionEnabled = false` directly. Correct only because it has no
  subviews to cut off; do not copy it into a view that has children.

`FLHitTestingTests` pins all of this down. The load-bearing one is *a tower of wrappers passes a touch
through all of them* — it is the case that fails under frame containment and passes here.
