# Value Expression Rules

How to produce a value: at the point of declaration, in steps small enough for the type checker.

Two rules that bound each other. The first says *don't defer* a binding's value; the second says *don't cram* the whole derivation into one expression. Applying either alone produces bad code.

## 1. A binding gets its value at declaration

Never declare a binding without a value and fill it in from branches.

```swift
// no
let resolvedWidth: CGFloat
if let width {
    resolvedWidth = context.clampingWidth(width)
} else {
    resolvedWidth = context.width.or(0)
}

// yes
let resolvedWidth = width.map(context.clampingWidth(_:))
    .or(context.width)
    .or(0)
```

Three mechanisms cover almost every case:

| Instead of | Write |
| --- | --- |
| `??`, or `if let x { a = … } else { a = … }` | `.or(_:)` from `Optional+Extensions`, chained |
| `let x: T` followed by `if`/`switch` assigning into it | `let x = if …` / `let x = switch …` |
| `switch` with a `return` in every case | `return switch … { }` |

A pre-declared binding separates the name from its meaning: the reader must scan every branch to learn what the value *is*, and definite-initialization analysis becomes the only thing proving the branch set is total. Expression form makes totality structural and reads top-down.

## 2. Keep each expression short — name the intermediate steps

The unit is one derivation *step*, not one statement chain. Bind intermediates to names rather than composing a long inline chain.

```swift
// no — one long derivation inside a larger expression
CGSize(
    width: width.map(context.clampingWidth).or(context.width.or(0)),
    height: context.clampingHeight(height)
)

// yes
let resolvedWidth = width.map(context.clampingWidth(_:))
    .or(context.width)
    .or(0)

return CGSize(width: resolvedWidth, height: context.clampingHeight(height))
```

Swift solves an expression as one constraint system, so ambiguity anywhere in it can resolve wrongly, and the diagnostic points at the whole expression rather than the bad sub-part. Long chains also drive compile time superlinearly — "expression too complex" comes from exactly this.

Two failure modes seen in practice:

- **Overload resolution flips.** `Optional.or` has both a `Wrapped` and a `Wrapped?` overload. Bound to its own `let` and chained left to right, it resolves to the non-optional overload. Nested inside a call argument, the same logic picks the optional overload and the result is unexpectedly `Optional`.
- **Literals in `if`/`switch` expression branches don't get the contextual type.** Branches are typed independently, so a bare `0` next to a `CGFloat` branch infers as `Int` and fails with "branches have mismatching types". Annotate the binding: `let gap: CGFloat = switch … { }`. The annotation is not deferred assignment and does not violate rule 1.

## When not to apply

- **A branch needing multiple statements stays a statement.** Forcing it into an expression duplicates subexpressions.
- **Two derived values sharing a condition, where one depends on the other:** use two sequential expressions, not a tuple from one `switch`.
- **Keep `if let` when the unwrapped value is used for more than the fallback.** `.or` replaces coalescing, not binding.
- **Short single-line ternaries are fine** — `direction == .leftToRight ? leading : trailing`. Reach for an `if` expression when a branch does not fit on the line or contains a compound expression.
