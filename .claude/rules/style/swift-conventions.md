# Swift Conventions

Language-level rules: how Swift is written here, independent of what is being built.

[value-expressions.md](value-expressions.md) owns how a value is derived and this file defers to it.
Where prose goes — doc comments, source comments, rule files — is
[rationale-placement.md](rationale-placement.md).

## Branching on an enum is a switch over every case

A branch that chooses *behaviour* per case lists every case, with no `default`. `FLProposal` states the
reason in its own doc comment — the cases exist "so that adding a case is a compile error in every node
that has to answer it" — and [../architecture/layout-proposals.md](../architecture/layout-proposals.md)
spends a whole rule reasoning case by case over the four. A `default:` throws that away: a fifth case
silently takes whichever branch happened to be the fallback, in every node at once, and the compiler
says nothing.

There is currently no `default:` in any `switch` in `Sources/`. Keep it that way.

```swift
// no — a fifth case rides the default, and .minimum/.maximum already differ
switch proposal {
case let .exact(value): clamp(value, min: lower, max: upper)
default: .unspecified
}

// yes
switch proposal {
case let .exact(value): .exact(clamp(value, min: lower, max: upper))
case .unspecified: pinned(min: lower, max: upper).map(FLProposal.exact).or(.unspecified)
case .minimum, .maximum: proposal
}
```

Grouping cases that genuinely share behaviour on one line — `case .minimum, .maximum:` — is the way to
say "these two are the same", and it still breaks when a case is added.

### Where `==` and `guard case` stay right

Comparing against a single case is correct when the code filters one case and treats every other
uniformly, or derives one value:

```swift
guard context.width != .minimum, context.height != .minimum else { return .zero }
direction == .leftToRight ? leading : trailing
var scrollsVertically: Bool { self != .horizontal }
guard case let .exact(value) = self else { return nil }
```

The test: if two or more cases each get behaviour of their own, it is a `switch`.

## No false optionals

A property is optional only when a real flow produces nil. Before writing `?`, name the call site that
passes nothing — if the only ones are a preview, a test fixture or a default, it is not optional; give
those call sites a value instead. A false optional charges every reader an unwrap whose nil branch
cannot happen, and hides unreachable behaviour behind it.

`FLProposal` is the worked example of the alternative: "nothing was proposed" is the case
`.unspecified`, not `nil`, and `.minimum` / `.maximum` are cases rather than `0` / `.infinity`. Every
row of the parity table in `layout-proposals.md` depends on `.unspecified` being distinguishable from
`.exact(0)` — collapsing either into an optional or a sentinel would make the distinction unstateable.

Two habits manufacture false optionals:

- **Borrowed from UIKit.** A UIKit signature that accepts nil says what UIKit tolerates, not what a node
  produces. `FLContext.init(width: CGFloat?, …)` takes an optional deliberately, at the boundary, and
  widens it to a case immediately (`width.map(FLProposal.exact).or(.unspecified)`). That is where an
  optional belongs — converted on the way in, not stored.
- **Left over from a refactor.** Collapsing a two-case enum into `T?` is right while the "none" case is
  reachable. When the last producer of that case goes, the optional goes with it — and check what the
  nil branch did, because that behaviour disappears too.

## Bounds and clamping

- A two-sided clamp against the proposal goes through `FLContext.clampingWidth(_:)` /
  `clampingHeight(_:)`. `FLFrame.clamp(_:min:max:)` is the private variant for optional bounds and stays
  file-local — it is not the general helper.
- Never hand-nest `min(max(…))`. There is none in the package today.
- Where a single bound stands alone, order the arguments ascending, so the call reads like a range and
  the bound sits on the side it acts from: a floor is `max(lower, x)`, a cap is `min(x, upper)`.
  `FLProposal.inset(by:)` already reads `Swift.max(0, value - amount)`.

## Two peers share a helper; neither calls the other

When two operations do the same work over different data, both call one private helper. The variant that
does more must not be built by calling the variant that does less.

`FLText` resolves its stored string twice, for two different consumers: `resolvedText(in:)` fills the
font and the colour for rendering, `measuredText(in:)` fills the font alone for `layout(in:)`. Written as
a chain it looked economical — the resolved string *is* the measured string plus a colour:

```swift
// no — the render path now depends on the measurement path
public func resolvedText(in environment: FLEnvironment) -> NSAttributedString {
    let filled = NSMutableAttributedString(attributedString: measuredText(in: environment))
    …
}
```

```swift
// yes — both are peers over one helper
public func resolvedText(in environment: FLEnvironment) -> NSAttributedString {
    let resolved = environment.applying(overrides)

    return text(withDefaults: [
        .font: resolved.font.or(Self.defaultFont),
        .foregroundColor: resolved.foregroundColor.or(Self.defaultColor),
    ])
}

func measuredText(in environment: FLEnvironment) -> NSAttributedString {
    let resolved = environment.applying(overrides)

    return text(withDefaults: [.font: resolved.font.or(Self.defaultFont)])
}
```

Name the helper for what it returns and what the argument means to it, not for the step it performs. The
first draft here was `filling(_:)`, which answers neither "filling what?" nor "filling it with what
authority?" — `text(withDefaults:)` says it returns the text and that the attributes lose to anything the
string already carries, which is the precedence rule the two callers depend on.

Two things are wrong with the chain and only one of them is about coupling. It **points the dependency
the wrong way**: measurement exists to be cheap and colour-free, and rendering is the richer path, so a
change made for the measurement path silently reaches drawing. And it **invents a hierarchy that is not
in the domain** — neither string is a special case of the other; they are two projections of the same
stored string, and the helper is what says so.

The tell is a reader who has to open the callee to understand the caller, for a caller that does not
otherwise care about it. Saving an allocation is not a reason to chain: the chain here cost the render
path a second `NSMutableAttributedString` copy, so it was not even the cheaper shape.

## Declarations

- **No leading-dot `.init(...)` — spell the type.** A node file names three closely related types in
  one breath (`FLPadded`, `FLPaddedLayout`, `FLPaddedView`), and a `layout(in:)` body returns one of
  them, so `.init` removes the one word that says which. Bare method references (`map(FLProposal.exact)`)
  are fine and are used throughout.
- **No free functions.** There are none; everything hangs off a type. A measurement helper is a
  `private static` member or a private extension under a `// MARK: - Helpers`, per
  [../architecture/file-organisation.md](../architecture/file-organisation.md).
- **No `Constants` entry for a value used once.** Inline it; extract for genuine reuse.
  `FLViewRegistry.Constants` earns its nesting because the identifiers it holds are built and matched in
  two places.
- **Declarations that each fit on one line are written as a run, with no blank lines between them** —
  `FLDecoration`'s seven stored properties, `FLProposal`'s cases, a layout struct's fields. A blank line
  separates one *group* from the next (stored properties from computeds, properties from methods, as in
  `FLContext`), or precedes a declaration whose body spans lines. It is never punctuation between
  neighbours of the same kind. Neither the compiler nor a formatter enforces this. Where a one-liner
  carries a doc comment, the comment is the separator and the run is broken anyway — which is why
  `FLProposal`'s cases are spaced and `FLDecoration`'s properties are not.
- **A call that does not fit one line puts every argument on its own line, and the closing paren on
  its own.** Not a hanging bracket that keeps the first argument on the call line:

  ```swift
  // no
  return text(withDefaults: [
      .font: resolved.font.or(Self.defaultFont),
      .foregroundColor: resolved.foregroundColor.or(Self.defaultColor),
  ])

  // yes
  return text(
      withDefaults: [
          .font: resolved.font.or(Self.defaultFont),
          .foregroundColor: resolved.foregroundColor.or(Self.defaultColor),
      ]
  )
  ```

  The hanging form reads as one argument even when there are three, and the indentation of the last line
  no longer says where the call ends. `FLText`'s own initialiser calls and `NSTextContainer(size:)` were
  already written the second way; it is one line either way at the point of the label.
- **The same inside a body.** A blank line groups statements; it does not punctuate a binding and the
  `return` that consumes it. `let resolved = …` followed by a blank line and a one-line `return` using
  `resolved` is three lines of body for one derivation. Keep the blank line where what follows spans
  lines, or where a genuine second phase begins — a guard block, then the work.
