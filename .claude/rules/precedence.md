# Rule Precedence

These rules are the authority on this package. Code that breaks one is **legacy, not precedent**.

"I matched the file I was editing" is not a justification. Every rule here was written after the code
it governs, so a neighbouring declaration is evidence of what was written once, never of what should be
written now. Before copying the shape of an adjacent declaration, check whether a rule covers it. When
the two disagree, follow the rule.

## Which rule wins

The two folders own different questions and defer to each other on the rest:

| folder | owns | example |
| --- | --- | --- |
| `style/` | how a body is written — expressions, branching, declarations, where prose goes | `value-expressions.md` decides whether a value is derived in one expression or three |
| `architecture/` | what a type is, what it must expose, and where it lives | `file-organisation.md` decides which file the type goes in |

`file-organisation.md` is authoritative for placement, including for the rules added since it was
written. On a question of syntax inside a body, `style/` wins even where an architecture rule shows a
snippet spelling it differently — the snippets there are about structure and are not maintained as
style examples.

## The three shapes most likely to be copied

Each is a deliberate exception sitting in a file you are likely to have open, which is exactly what
makes it dangerous:

- **A hand-written `==` / `hash(into:)`.** [architecture/node-equality.md](architecture/node-equality.md)
  says synthesis, always. Three nodes break that on purpose — `FLTuple` and `FLComposed` because a
  parameter pack and a stored existential cannot be compared field-wise, `FLImage` because
  `UIImage.isEqual:` is unbounded work on a cache probe. A new node does not join that list by
  resemblance; it needs the same kind of argument, and in `FLImage`'s case a measurement.
- **A leaf view subclassing a UIKit control.** `FLTextView: UILabel` passes the test in
  [architecture/leaf-views.md](architecture/leaf-views.md) — `UILabel` declares no designated
  initialiser, so `init()` is inherited. `UIImageView` does declare one, and the subclass that looked
  identical produced `EXC_BAD_ACCESS` as soon as it was wrapped. The rule is the init test, not the
  precedent.
- **`UIView` as a node view's base class.** The default is `FLStructuralView`; only a view that draws
  its own content takes `UIView`. The overwhelming majority of views are structural, but the handful
  that draw — `FLColor`, `FLImage`, `FLText` — are the leaves you read first, so `UIView` is what you
  are most likely to have seen. Getting this wrong is invisible until an unrelated screen finds a
  button that will not tap.

## Leave legacy alone

Following a rule applies to what you write. Do not churn pre-existing violations in code you are not
otherwise changing — a diff that rewrites twenty untouched declarations buries the change it came for,
and [style/commit-messages.md](style/commit-messages.md) then has no manifest to state. When a file
needs both, the mechanical pass is its own commit.
