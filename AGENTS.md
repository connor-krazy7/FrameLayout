# Agent Instructions

Prototype of **FrameLayout** (`FL*`) — a declarative, SwiftUI-shaped content system for UIKit whose
layout is precomputed off the main thread. Explores whether the AI-conversation cells in `ios-app`
can be described as composition instead of hand-nested initialisers.

## Where things live

The package is the repository root, the demo app is an example of consuming it:

| path | contents |
| --- | --- |
| `Package.swift`, `Sources/FrameLayout/` | the framework |
| `Tests/FrameLayoutTests/` | the framework's own tests, benchmarks, and `Fixtures/` |
| `Examples/Playgrounds.xcodeproj`, `Examples/Playgrounds/` | the demo app: playgrounds, previews, demo models |
| `Examples/PlaygroundsTests/` | tests that are *about the demo* — playground rows, the conversation cell |

Inside `Sources/FrameLayout/`, `Core/` is the vocabulary, `Leaves/` `Containers/` `Modifiers/`
`Controls/` are the nodes, `Group/` is the builder machinery, `Composition/` is `FLView` and
`FLComposed`, and `Runtime/` is everything that drives a description: hosting, measurement, caching, the
registry, frame application. Which file a declaration goes in, what a folder means, and how a file is
ordered internally are all `.claude/rules/architecture/file-organisation.md`, which is authoritative —
do not re-derive it from this paragraph.

The example app links the root package by relative path, so it compiles against `public` API only —
that is what proves the surface is complete. Both test targets use `@testable import FrameLayout`,
since they assert on internals: child frames inside layout structs, registry bookkeeping,
`FLText.resolvedText`.

`Fixtures/` in the package suite is the cross-cutting set every area may draw on: a small item model, a
four-level composite row, a swatch generator, and two injected UIKit views, one laying out by frames and
one by constraints. Which target a suite belongs in is `.claude/rules/testing.md`; which folder inside
it, and where a `FL*TestsFixtures.swift` file sits, is the file-organisation rule.

Neither side needs project edits when files are added — `Examples/Playgrounds/` is a file-system
synchronised group and SwiftPM discovers package sources by path.

Access control notes that cost a build cycle each: a `public extension` block makes its members public,
but a **nested** type needs its own `public`, and a struct that consumers construct needs an explicit
`public init` because the synthesised memberwise one stays internal. `FLStructuralView` is `public`, not
`open`, so a leaf defined outside the package cannot subclass it — that is what `FLUIViewRepresentable`
is for.

## Project rules

The authoritative project rules live in `.claude/rules/` and are shared across all agents.
Claude Code loads that directory directly; other agents should read the files listed here.

- `.claude/rules/precedence.md` — the rules outrank the neighbouring declaration, which folder owns which question, and the three deliberate exceptions most likely to be copied
- `.claude/rules/testing.md` — run `make test` before believing a change is done, which target a suite goes in, the `#expect` traps, and what a green run does not cover
- `.claude/rules/style/value-expressions.md` — producing values at declaration, and keeping expressions short enough to infer
- `.claude/rules/style/swift-conventions.md` — exhaustive switches over an enum, no false optionals, clamping, and declaration layout
- `.claude/rules/style/rationale-placement.md` — which of the three homes a piece of reasoning goes in: a rule file, a comment, or the commit message
- `.claude/rules/style/commit-messages.md` — a manifest of what changed first, the reasoning after
- `.claude/rules/architecture/file-organisation.md` — one file per nameable thing, why a node's Layout/Node/View triple is the exception, and what each folder means
- `.claude/rules/architecture/concurrency.md` — never touch a `UIView` while measuring, what a measurement may touch, and which instrument protects state that outlives one
- `.claude/rules/architecture/leaf-views.md` — wrap UIKit controls rather than subclassing them; picking `FLStructuralView` vs `UIView` and how hit-test pass-through works
- `.claude/rules/architecture/node-equality.md` — let `Hashable` synthesis produce a node's `==`/`hash`, and why no identity fast path
- `.claude/rules/architecture/layout-proposals.md` — a proposal is a question, not a constraint; only a pinned frame hands a size down, and how to measure parity against real SwiftUI

## Architecture

Three parallel type trees, linked by mutually recursive associated types:

| role | protocol | notes |
| --- | --- | --- |
| description | `FLNode` | `Sendable`, `Hashable`; measured off the main thread |
| renderer | `FLNodeView` | `@MainActor` `UIView`; created once, never re-created for a given node type |
| geometry | `FLLayout` | precomputed frames, `Equatable`, cacheable |

`FLNode.layout(in: FLContext)` is a pure function of `(node, context)`. Nothing in a view's internal
state may influence its size — that invariant is what buys off-main layout and caching, so a node
must never hold closures, handlers, or view references.

- `FLContext` carries an `FLProposal` per axis (`width`/`height`) plus the environment. The cases are
  `.unspecified` / `.minimum` / `.maximum` / `.exact`; there is no sentinel value and no optional.
- Containers take a group (`FLGroup`); `FLConcat` is a parameter-pack group, so a stack's children are
  statically typed at any arity.
- Modifiers wrap by default. Only `cornerRadius` / `clipped` merge into an existing `FLDecorated`,
  and `opacity` / `allowsHitTesting` into an existing `FLAdjusted` — clips compose and adjustments are
  layout-neutral. `background` and `border` must wrap so translucent colours composite and fills escape
  an outer clip.
- `FLLayoutCache` is unbounded and generic over one concrete `Node`, so a screen with several cell
  kinds needs one cache each and a data reload has to call `removeAll()`. Both limits are documented on
  the type. `FLLayoutComputer` is a convenience over `Task.detached`, not a requirement — a caller with
  its own queue measures directly.
- `if` / `if let` / `else if` in a builder produce `FLEither` and `FLOptional`, so both branches stay
  statically typed. Groups flatten: a group contributes *N* children to its parent, so an absent branch
  contributes none and the stack never spends spacing on it. `FLForEach` is the same mechanism at
  runtime arity.

## Build settings that are load-bearing

- `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. With `MainActor` defaults, `FLNode.layout(in:)`
  becomes main-actor isolated and off-main measurement stops compiling.
- `SWIFT_VERSION = 6`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- The Xcode project uses a file-system-synchronised group, so new files under `Playgrounds/` are
  picked up without editing the project file.

## Verifying changes

```sh
make test              # both suites — run this before believing a change is done
make build-package     # fastest loop: no app, no simulator boot
```

`make build-package` catches everything inside the framework, access-control mistakes included, but not
a public surface missing something the example needs — only building the app does that.

The rest is `.claude/rules/testing.md`: which target a suite goes in, the two `#expect` traps,
`Issue.record` instead of `print`, the parameter-pack codegen check, what the benchmarks can and cannot
tell you, and the gaps a green run does not cover.

