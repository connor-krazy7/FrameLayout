# Commit Message Rules

How a commit message is shaped: what changed first, why it changed after.

## Subject line: what, imperatively

`Add FLScroll, a scrolling region inside a tree`. Not `Scroll improvements`, not
`Why bounded frames matter`. Under ~72 characters, no trailing period.

## Then the manifest, as points

Name what was added or changed — types, public APIs, files, test suites, docs — as a list, one point
per nameable thing. Someone scanning the log to find where a symbol came from should not have to open
the diff, and should not have to read a paragraph to find the one line that names it.

```
- Add `bindView(withTag:as:)` in two forms, with and without a binding key,
  which hand the closure the view of that kind inside the tagged region.
- Extract the match-or-search resolution as `FLViewRegistry.resolve`, and route
  `view(withTag:as:)`, `bindButton` and `button(withTag:)` through it, so a
  button inside a tagged wrapper is now found rather than only one that
  registered itself directly.
- Cover both spellings in `FLTypedBindingTests`, and document them in the README.
- `make test` passes: 335 package tests in 47 suites, 42 example tests in 9.
```

Each point opens with the verb that names the change — `Add`, `Extract`, `Rename`, `Delete`, `Correct`,
`Move` — and carries the symbol or the path. A point that needs a second clause to say what the thing is
*for* is fine; one that starts arguing has crossed into the next section.

The test result is the last point, and it reports a run that happened. A docs-only change says so
instead.

Continuation lines indent two spaces, so the list survives `git log` without a terminal reflowing it
into prose.

Behaviour counts as *what* only when it names the thing that behaves. "The content is measured unbounded
along the axis" describes a design; it does not tell a reader that a `UIScrollView` subclass and nine
modifiers arrived.

## After that: why, in prose

Why the change looks like this, and why now. This is the part a diff cannot recover later, and it
belongs *below* the manifest, never instead of it.

Paragraphs, not points. The manifest is a list because it is a set of independent facts to scan; an
argument has a thread, and bulleting it drops the connectives that carry the reasoning.

### The durability test: will this reasoning govern the next change?

**If yes, it is a rule and the commit points at it. If it explains only why this diff looks the way it
does, it is the commit's own.** [rationale-placement.md](rationale-placement.md) is authoritative on the
split; this section is the commit's half of it.

| the commit's own | a rule's, cited from the commit |
| --- | --- |
| what was observed that prompted the change | the standing prohibition it produced |
| what the code did before, and what that cost | the table or the number a reader must not undo |
| an approach tried during this change that failed | a rejected alternative that will tempt the next author too |
| what is still unfinished, and what was deliberately left out | the test that decides the next case |

So a commit that lands a rule says **what changed in the rule and why now** — it does not restate the
rule's argument. Two copies of an argument drift, and the commit is the copy nobody re-reads.

Worth recording, all of it the momentary kind: a number this change measured; a plausible-looking
approach that was tried here and failed; a behaviour that surprised the author and is now pinned by a
test; a claim the change could not verify and left open. Where one of those turns out to govern the
next change too, it goes in a rule file *in the same commit*, and the message names the file.

## The failure this rule exists for

A body that is all rationale. It reads well and answers a question nobody asked yet, while leaving the
reader unable to tell whether code or only documentation landed:

```
A corner radius is part of a node's identity but changes no size, so a cache
keyed on the node misses and re-measures the subtree for an identical result.
It rarely bites, because a radius is normally a constant in the body rather
than data …
```

The same commit, with a manifest first:

```
- Add `FLDecorationCostTests`, pinning that a corner radius is layout-neutral,
  that it changes node identity so a cache keyed on the node misses, and that
  corner selection rides in the layout while the radius is applied at update.
- Note the two `#expect` traps in `AGENTS.md`.

The cache consequence rarely bites, because a radius is normally a constant
in the body rather than data. Driving one from state pays a full re-measure
per flip for an identical size, and FLLayoutCache is only ever keyed at the
root, so nothing memoises below it.
```

## Do not

- Narrate the process. "I first tried a protocol conformance, then discovered…" becomes "UIColor is a
  non-final class, so it cannot satisfy FLNode's View.Node == Self requirement."
- Claim a result that was not run. If the suite was not executed, the message does not say it passed.
- Pad with counts that the diff already carries, such as line totals.

## Wrapping and trailers

Wrap the body at ~80 characters. End with both trailers, after a blank line:

```
Co-authored-by: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_<id>
```

Both, every time. The session trailer is the only link from a commit back to the conversation that
produced it, which is where the reasoning that did not fit the message still lives — and it is the
first thing wanted when a decision has to be revisited a month later. Git trailers are
case-insensitive, so an older `Co-Authored-By:` in the log is the same trailer, not a different one.

If a session id is genuinely unavailable, say so in the PR rather than dropping the line silently: a
missing trailer is indistinguishable from a commit nobody bothered to attribute.
