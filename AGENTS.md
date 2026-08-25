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

Inside `Sources/FrameLayout/`, a file is named after the type in it and holds nothing else — except a
node, whose `Layout` and `View` share its file because the three are one mutually recursive
declaration. A node with companion types gets a folder named after it without the `FL` prefix
(`Containers/Grid/`, `Modifiers/Decorated/`); one without stays a plain file. Inside a file the entry
point comes first — the `FLNodeProviding` verb in `Modifiers/`, the type itself everywhere else — then
the node with its extensions, then the layout, then the view. `Core/` is the vocabulary, `Leaves/` `Containers/` `Modifiers/` `Controls/` are the nodes,
`Group/` is the builder machinery, `Composition/` is `FLView` and `FLComposed`, and `Runtime/` is everything
that drives a description: hosting, measurement, caching, the registry, frame application. The
file-organisation rule below is authoritative.

The example app links the root package by relative path, so it compiles against `public` API only —
that is what proves the surface is complete. Both test targets use `@testable import FrameLayout`,
since they assert on internals: child frames inside layout structs, registry bookkeeping,
`FLText.resolvedText`.

Which target a test belongs in follows from what it is *about*. Framework behaviour goes in
`Tests/FrameLayoutTests/` and depends only on `Fixtures/` — a small item model, a four-level composite
row, a swatch generator, and two injected UIKit views, one laying out by frames and one by constraints.
A test that asserts something about a playground or the demo conversation cell stays in
`Examples/PlaygroundsTests/`. If a framework test needs a demo type, the fixture is missing something;
add to `Fixtures/` rather than reaching across.

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

- `.claude/rules/style/value-expressions.md` — producing values at declaration, and keeping expressions short enough to infer
- `.claude/rules/style/commit-messages.md` — a manifest of what changed first, the reasoning after
- `.claude/rules/architecture/file-organisation.md` — one file per nameable thing, why a node's Layout/Node/View triple is the exception, and what each folder means
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

Everything goes through the `Makefile`, which derives the simulator UDID by name so no machine-specific
id is baked into a command:

```sh
make test              # both suites
make test-package      # Tests/FrameLayoutTests
make test-examples     # Examples/PlaygroundsTests
make build-package     # fastest loop: no app, no simulator boot
make test SIMULATOR="iPhone 16 Pro"
```

`make build-package` catches everything inside the framework, including access-control mistakes. It
does **not** catch a public surface missing something the example needs, which is what building the app
does — so run `make test` before believing a change is done.

`FrameLayout.xcworkspace` holds the package and the example project, so one Xcode window covers both
and ⌘U runs whichever scheme is selected. Both schemes are committed under `xcshareddata`; the
package's auto-generated scheme has no test action when driven through a workspace, which is why the
workspace ships its own.

The package suite runs **unhosted** — no host app — and window-dependent behaviour still works there:
`UIWindow`, hit-testing, `didMoveToWindow` teardown, and `ImageRenderer` were all verified under it.

`print` from a test reaches neither the log nor the result bundle; use `Issue.record` to get numbers
out.

Two `#expect` traps that look like real failures and are not. Arithmetic over more than one literal
infers `Int`, so `#expect(width == 8 * 60 + 7 * 4)` fails as `508.0 == 508` — swift-testing compares the
captured values as `Any`, and the dynamic types differ. The same happens when a `CGFloat` meets a
`Double` produced by literal division. Wrap the expression in `CGFloat(...)` or annotate the binding. A codegen check is still worth running when parameter packs change:

```sh
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

xcrun swiftc -emit-object -wmo -swift-version 6 \
  -enable-upcoming-feature MemberImportVisibility -O -module-name FrameLayout \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator -o /tmp/fl.o \
  $(find Sources -name '*.swift' | sort)
```

Typecheck alone is not sufficient: parameter packs have hit SILGen crashes that only appear at
codegen. Storing a pack expansion in a returned struct crashes Swift 6.2.1, which is why
`FLGroupChildren` holds `[FLAnyLayout]` rather than `(repeat (each Child).Layout)`.

The package boundary now enforces what a hand-rolled two-step `swiftc` check used to: app and test
sources cannot silently merge into one module with the framework, so a missing import is a real error
rather than something that resolves by accident.

Report timings and pass/fail from an actual test run, never from a clean build.

To read the concrete type of a modifier chain, force a mismatch and let the compiler print it:

```swift
func probe() { let chain = FLBox(width: 40, height: 40).background(.systemBlue); let _: Never = chain }
```

Benchmarks live in `PlaygroundsTests/Benchmarks/` — same target as the tests, so they are runnable from
the test diamond and inspectable in the navigator, and they get the simulator runtime (UIKit types are
measurable there). They assert on semantics only and print timings; a Debug test build is `-Onone` and
inflates every figure, so switch the test action to Release before trusting absolute numbers. Each
suite documents its own results table.

Visual behaviour is checked against SwiftUI side by side in `Demo/FLChainPreview.swift`
(previews: `all cases`, `padding + background`, `alpha compositing`, `lineLimit + alignment`) and
`Demo/FLImageComparison.swift` (intrinsic vs resizable, aspect ratio, content mode, tinting).

Layout parity is also asserted numerically: `FLSwiftUIParityTests` measures FL's computed sizes against
real SwiftUI through `UIHostingController.sizeThatFits(in:)`. See the layout-proposals rule for what that
measurement can and cannot tell you.
