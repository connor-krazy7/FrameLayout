# Rationale Placement Rules

Reasoning is worth keeping in this package — it is most of what the package has produced. This file
decides *where* a given piece of it goes, because right now some of it lives in three places at once.

## Three homes, one job each

| home | holds | authority |
| --- | --- | --- |
| `.claude/rules/**` | the argument: measurement tables, parity numbers, rejected alternatives, the constraint that forced a shape | yes — this is where a reader is sent |
| a doc or source comment | the contract a caller cannot infer from the signature, and invariants that would otherwise break silently | no — it points at the rule |
| the commit message | what changed and why it changed then; see [commit-messages.md](commit-messages.md) | no |

The split is not about length. It is about which copy someone has to update when the behaviour changes.
The test that decides the first row against the third is durability — will this reasoning govern the
next change, or does it only explain this diff — and `commit-messages.md` states it from the commit's
side.

## What earns a comment

A comment stays when it changes what a **caller does**, or when the code beside it would be broken by a
plausible edit that looks harmless. The good ones in the package are all one of those:

- `FLProposal` — why the cases are cases and not sentinels, in two sentences. It is the reason a reader
  does not "simplify" `.minimum` into `0`.
- `FLLayoutCache` — unbounded, one cache per node type, only ever keyed at the root. Three facts a
  caller must plan around and none of them visible in the signature.
- `FLLayoutComputer` — "a convenience, not a requirement". Without it the type reads as the sanctioned
  way to measure.
- `FLText.resolvedText(in:)` — the precedence order of attributes, and that it is called twice.
- `FLShape` — the commented-out `case path` and why it is absent. Commented-out code is otherwise banned;
  this one states what it would cost (an offscreen composite per view, no continuous corners, and the
  loss of `Hashable`/`Sendable` synthesis on `FLDecoration`) and what would make it worth adding. That is
  the bar for the exception, and it is the one block here with no rule-file home — a design boundary
  rather than a behaviour, so it belongs at the declaration it is about.

## What belongs in a rule file instead

Prose that *argues* — that compares alternatives, carries numbers, or would need rewriting if a
measurement changed. Two blocks in `Sources/` are currently a second copy of an argument the rules
already make in full:

- `FLAspectRatio.swift` opens with six lines on why a cap bounds both axes. `layout-proposals.md` makes
  the same case under "Reserving a box that hugs a ratio-driven image", with the three equivalent
  spellings and the `.fill` reason the comment compresses into one clause.
- `FLFrame.swift` carries two blocks on what a bounded frame may propose. `layout-proposals.md` opens
  with that rule, the code it replaced, and the two bugs that came out of the earlier version.

Neither is wrong today. Both are a duplicate that will drift, and the source copy is the one that will
be left behind, because a behaviour change is made in the file and recorded in the rule.

**When you change one of those behaviours, the rule file is what must change**, and the comment shrinks
to a pointer — `// A cap bounds both axes; see layout-proposals.md.` — or goes. Do not do that
mechanically to blocks you are not otherwise touching; per [../precedence.md](../precedence.md), a
sweep is its own commit.

## Never write these

The species that are always spam, no matter what surrounds them:

- narration — `// Measure the child` above a call to `layout(in:)`
- restating the name — `/// The corner radius` on `let cornerRadius`
- a change journal — `// Now uses the two-pass measurement`
- reviewer-directed asides — `// This is safe because the lock is held above`
- section headers that are not `// MARK: -`
- commented-out code with no argument beside it (`FLShape` is the standard to meet, not a licence)
- a doc comment on a protocol requirement describing what an implementation does — `layout(in:)` states
  the contract, not how `FLStack` fulfils it

The test that separates a spam comment from a real one: does it tell a caller something, or does it
justify the code to whoever is reading the diff? If it justifies, it is a commit message or a rule in
the wrong file.
