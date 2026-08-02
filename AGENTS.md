# Agent Instructions

Prototype of **FrameLayout** (`FL*`) — a declarative, SwiftUI-shaped content system for UIKit whose
layout is precomputed off the main thread. Explores whether the AI-conversation cells in `ios-app`
can be described as composition instead of hand-nested initialisers.

## Project rules

The authoritative project rules live in `.claude/rules/` and are shared across all agents.
Claude Code loads that directory directly; other agents should read the files listed here.

- `.claude/rules/style/value-expressions.md` — producing values at declaration, and keeping expressions short enough to infer
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
- Containers take a group (`FLGroup`); `FLTuple` is a parameter-pack group, so a stack's children are
  statically typed at any arity.
- Modifiers wrap by default. Only `cornerRadius` / `clipped` merge into an existing `FLDecorated`,
  and `opacity` / `allowsHitTesting` into an existing `FLAdjusted` — clips compose and adjustments are
  layout-neutral. `background` and `border` must wrap so translucent colours composite and fills escape
  an outer clip.
- `if` / `if let` / `else if` in a builder produce `FLEither` and `FLOptional`, so both branches stay
  statically typed. Groups flatten: a group contributes *N* children to its parent, so an absent branch
  contributes none and the stack never spends spacing on it. `FLForEach` is the same mechanism at
  runtime arity.

## Build settings that are load-bearing

- `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. With `MainActor` defaults, `FLNode.layout(in:)`
  becomes main-actor isolated and off-main measurement stops compiling.
- `SWIFT_VERSION = 6`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- The Xcode project uses a file-system-synchronised group, so new files under `CellSystem/` are
  picked up without editing the project file.

## Verifying changes

Do not run `xcodebuild`. Typecheck and codegen from the command line, matching the project settings:

```sh
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
FILES=$(find CellSystem -name '*.swift' | sort)

xcrun swiftc -typecheck -swift-version 6 -default-isolation nonisolated \
  -enable-upcoming-feature MemberImportVisibility \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator $FILES

xcrun swiftc -emit-object -wmo -swift-version 6 -default-isolation nonisolated \
  -enable-upcoming-feature MemberImportVisibility -O -module-name CellSystem \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator -o /tmp/cs.o $FILES
```

Typecheck alone is not sufficient: parameter packs have hit SILGen crashes that only appear at
codegen. Storing a pack expansion in a returned struct crashes Swift 6.2.1, which is why
`FLTupleLayout` holds `[FLAnyLayout]` rather than `(repeat (each Child).Layout)`.

Check the test target in **two steps**, against a real module. Do not throw the app and test sources
into one `swiftc` invocation: that merges both into a single module, so a test file missing its
`@testable import CellSystem` still resolves internal symbols and passes — a check that cannot fail on
the mistake it exists to catch.

```sh
common=(-swift-version 6 -default-isolation nonisolated \
  -enable-upcoming-feature MemberImportVisibility \
  -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" -target arm64-apple-ios17.0-simulator)
frameworks=(-F "$(xcode-select -p)/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks" \
  -plugin-path "$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing")

xcrun swiftc -emit-module -wmo -enable-testing -module-name CellSystem "${common[@]}" \
  -emit-module-path /tmp/cs_mod/CellSystem.swiftmodule $(find CellSystem -name '*.swift' | sort)

xcrun swiftc -typecheck "${common[@]}" -I /tmp/cs_mod "${frameworks[@]}" \
  $(find CellSystemTests -name '*.swift' | sort)
```

Note `"${common[@]}"`, not `$common` — zsh does not word-split an unquoted parameter, so the flags
arrive as one bogus argument.

Neither command runs the tests. Report timings and pass/fail from an actual ⌘U run, never from a
clean typecheck.

To read the concrete type of a modifier chain, force a mismatch and let the compiler print it:

```swift
func probe() { let chain = FLBox(width: 40, height: 40).background(.systemBlue); let _: Never = chain }
```

Benchmarks live in `CellSystemTests/Benchmarks/` — same target as the tests, so they are runnable from
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
