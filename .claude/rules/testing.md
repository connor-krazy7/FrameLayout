# Testing Rules

How a change is verified, which target a suite goes in, and the traps that produce a failure or a
number you should not believe.

## Run `make test` before believing a change is done

Everything goes through the `Makefile`, which derives the simulator UDID by name so no machine-specific
id is baked into a command:

```sh
make test              # both suites
make test-package      # Tests/FrameLayoutTests
make test-examples     # Examples/PlaygroundsTests
make build-package     # fastest loop: no app, no simulator boot
make test SIMULATOR="iPhone 16 Pro"
```

| command | catches | misses |
| --- | --- | --- |
| `make build-package` | everything inside the framework, access-control mistakes included | a public surface missing something the example needs |
| `make test` | the above, plus both suites against the real simulator | — |

`make build-package` is the fast loop, but only building the app proves the public surface is complete,
so a change is not done until `make test` has run.

**Report pass/fail and timings from an actual test run, never from a clean build**, and never from
reasoning about what would pass. [style/commit-messages.md](style/commit-messages.md) makes the same
demand of a commit message: if the suite was not executed, the message does not say it passed.

## Put a suite where its subject lives

| the test is about | target |
| --- | --- |
| framework behaviour | `Tests/FrameLayoutTests/`, depending only on `Fixtures/` |
| a playground, or the demo conversation cell | `Examples/PlaygroundsTests/` |

**If a framework test needs a demo type, the fixture is missing something.** Add it to `Fixtures/`
rather than reaching across into the example. Which folder inside the target, and where a
`FL*TestsFixtures.swift` file sits, is
[architecture/file-organisation.md](architecture/file-organisation.md).

Both targets use `@testable import FrameLayout`, since both assert on internals — child frames inside
layout structs, registry bookkeeping, `FLText.resolvedText`.

## Get numbers out with `Issue.record`, never `print`

`print` from a test reaches neither the `xcodebuild` output nor the result bundle. To surface a measured
value, accumulate it and fail on purpose: `Issue.record(Comment(rawValue: report))` puts the string in
the failure message.

## Two `#expect` traps that are not real failures

Both produce a failure that reads as a genuine mismatch:

- **Arithmetic over more than one literal infers `Int`.** `#expect(width == 8 * 60 + 7 * 4)` fails as
  `508.0 == 508` — swift-testing compares the captured values as `Any`, so the dynamic types differ.
- **A `CGFloat` meeting a `Double` produced by literal division** does the same.

Wrap the expression in `CGFloat(...)`, or annotate the binding.

## Benchmarks assert on semantics, never on a timing

They live in `Tests/FrameLayoutTests/Benchmarks/` — the same target as the tests, so they are runnable
from the test diamond, inspectable in the navigator, and get the simulator runtime where UIKit types are
measurable. A Debug test build is `-Onone` and inflates every figure, so **switch the test action to
Release before trusting an absolute number**; read ratios otherwise. Each suite documents its own
results table, and a rule that cites a figure names the suite that produced it.

## Run the codegen check when parameter packs change

`swiftc -typecheck` is not sufficient — parameter packs have hit SILGen crashes that appear only at
codegen:

```sh
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"

xcrun swiftc -emit-object -wmo -swift-version 6 \
  -enable-upcoming-feature MemberImportVisibility -O -module-name FrameLayout \
  -sdk "$SDK" -target arm64-apple-ios17.0-simulator -o /tmp/fl.o \
  $(find Sources -name '*.swift' | sort)
```

Storing a pack expansion in a returned struct crashes Swift 6.2.1, which is why `FLGroupChildren` holds
`[FLAnyLayout]` rather than `(repeat (each Child).Layout)`.

The package boundary now enforces what a hand-rolled two-step `swiftc` check used to: app and test
sources cannot silently merge into one module with the framework, so a missing import is a real error
rather than something that resolves by accident.

## Read a concrete chain type by forcing a mismatch

Let the compiler print it:

```swift
func probe() { let chain = FLColor(.systemRed).frame(width: 40, height: 40); let _: Never = chain }
```

## Verifying against SwiftUI

Numerically, `FLSwiftUIParityTests` measures FL's computed sizes against real SwiftUI through
`UIHostingController.sizeThatFits(in:)`, and renders with `ImageRenderer` to compare where a child
actually landed. What that measurement can and cannot tell you — in particular that `sizeThatFits` says
nothing about placement — is
[architecture/layout-proposals.md](architecture/layout-proposals.md). Add to that suite rather than
writing a throwaway probe.

Visually, the two systems sit side by side in `Demo/FLChainPreview.swift` and
`Demo/FLImageComparison.swift`.

## What the suites do not cover

Know the gaps before trusting a green run:

- **No timing is asserted anywhere.** The benchmarks print and assert on semantics, so a change that
  makes measurement ten times slower passes every suite. `layout-proposals.md` carries the cost tables
  that would notice, and they are read by hand.
- **`FLLayoutCache` has no suite of its own.** `FLOffMainMeasurementTests` covers concurrent probes and
  concurrent fills, and three suites cover hit and miss by using it as a tool, but nothing covers
  `removeAll()` under contention.
- **Off-main behaviour is covered for measurement only.** `FLOffMainMeasurementTests` is the one suite
  that leaves the main thread; see [architecture/concurrency.md](architecture/concurrency.md) for what
  it pins and what remains design.

Writing a test that leaves the main thread has two traps, both hit while writing that suite:

- **`Thread.isMainThread` is unavailable from an asynchronous context** in this target — though the same
  read compiles in the framework target, which sets `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. Read
  it from a synchronous `@MainActor` function, or use `pthread_main_np()`, which carries no such
  restriction.
- **A non-`Sendable` value cannot be sent into the task.** Passing an `NSAttributedString` to
  `Task.detached` fails to compile; build it from `Sendable` inputs inside the closure instead.

## Environment notes

The package suite runs **unhosted** — no host app — and window-dependent behaviour still works there:
`UIWindow`, hit-testing, `didMoveToWindow` teardown and `ImageRenderer` were all verified under it.

`FrameLayout.xcworkspace` holds the package and the example project, so one Xcode window covers both and
⌘U runs whichever scheme is selected. Both schemes are committed under `xcshareddata`; the package's
auto-generated scheme has no test action when driven through a workspace, which is why the workspace
ships its own.
