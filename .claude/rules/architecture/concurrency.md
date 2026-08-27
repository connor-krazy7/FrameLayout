# Concurrency Rules

What you may write inside a measurement, and which instrument protects state that outlives one.

Every rule here serves one invariant: `FLNode.layout(in:)` is a pure function of `(node, context)`,
callable from any thread. That is what buys off-main layout and makes `FLLayoutCache` sound. A node that
acquires hidden state breaks caching and thread-safety in the same edit.

## Never touch a `UIView` while measuring

`layout(in:)` runs on an arbitrary cooperative-pool thread. Do not create, read, size or configure a
`UIView` there — not the node's own view, not a throwaway instance, not a static one.

This is easier to get wrong than it sounds, because
[leaf-views.md](leaf-views.md) tells you to back a leaf by wrapping a UIKit control, which makes the
control's own sizing the obvious way to measure it:

```swift
// no — instantiates a UIView off the main thread, inside a pure function
func layout(in context: FLContext) -> FLTextLayout {
    let label = UILabel()
    label.attributedText = resolvedText(in: context.environment)
    return FLTextLayout(size: label.sizeThatFits(context.proposedSize))
}
```

`FLText` does not do this. It measures with
`NSAttributedString.boundingRect(with:options:.usesLineFragmentOrigin, .usesFontLeading)` and
re-implements line breaking over the string, which is most of why the file is as long as it is.

**Measure from the model, never from a view.** A leaf's metrics come from the data the node already
holds — the attributed string, the font, the image's `size` — plus the environment. If a control's size
genuinely cannot be derived that way, the node cannot be measured off the main thread and needs a
different design; say that rather than smuggling a view into the layout.

### What a measurement may touch

The allowlist, pinned by `FLOffMainMeasurementTests` for the two rows that call into UIKit:

| allowed | forbidden |
| --- | --- |
| value types, Foundation, Core Graphics | any `UIView` or `UIViewController` |
| `UIFont`, `UIColor`, `UIImage.size` | `UITraitCollection.current`, `UIScreen`, `UIApplication` |
| `NSAttributedString` metrics (`boundingRect`) | anything reading `@MainActor` state |
| `FLContext` / `FLEnvironment`, including `contentSizeCategory` | `Task`, `await`, a lock, a semaphore |

Environmental input arrives *through* `FLEnvironment` — that is what the type is for. A node reading
`UITraitCollection.current` instead is both a data race and a cache bug, since the value never reaches
the key the layout is memoised on.

Two rows of that table are **platform** behaviour this package depends on and does not control, so
`FLOffMainMeasurementTests` asserts them directly rather than trusting them:
`NSAttributedString.boundingRect` returns the same rect off the main thread as on it, and so do the
`UIFont` values `FLText` defaults to. If either changes, text measurement is what breaks, and it should
break there first.

**A non-`Sendable` value cannot be sent into a measurement task at all.** Handing an
`NSAttributedString` to `Task.detached` does not compile — *"sending value of non-Sendable type risks
causing data races"* — which is the constraint `FLText.attributedText` answers with
`nonisolated(unsafe)`. Build such a value from `Sendable` inputs on the side that needs it; that is also
the shape a real cache probe takes, per [node-equality.md](node-equality.md).

## Give a new node no isolation at all

A node and its layout are `Sendable` by synthesis and carry no annotation:

- Never write `@MainActor` on an `FLNode` or an `FLLayout`. The build setting
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` exists to stop that happening implicitly — under
  `MainActor` defaults, `layout(in:)` becomes isolated and off-main measurement stops compiling.
- Never write `@unchecked Sendable` on a node. See the two admissible relaxations below.
- Never annotate a node view either. `FLNodeView` is `@MainActor` on the protocol, so every conforming
  view inherits it.

**If a stored property blocks `Sendable` synthesis, change the property.** A closure, handler or view
reference belongs in `FLViewRegistry`, which is `@MainActor` and exists for it.
[node-equality.md](node-equality.md) reaches the same conclusion from the caching side.

## Pick the instrument by how the state is reached

For runtime state that outlives a measurement — a second cache, a coordinator, a prefetcher — choose by
reachability, not by taste:

| how it is reached | instrument |
| --- | --- |
| only from the main actor: views, frame application, registry bookkeeping | `@MainActor` |
| passed between contexts as a value | a `Sendable` value type, no annotation |
| **synchronously, from a `nonisolated` context** — i.e. from inside `layout(in:)` | `final class` + `NSLock` + `@unchecked Sendable`, the lock declared beside the `var` it guards |
| only from `async` contexts, never inside a measurement | `actor` |

`FLLayoutCache` is row three, and the reason it cannot be row four is structural: `layout(for:in:)` is
called from inside a node's `layout(in:)`, which `FLNode` declares as a synchronous function. An actor
would make the probe `async` and force `layout(in:)` to become `async` for every node in the package.

Use exactly one mechanism per piece of state. A lock inside an actor guards state the actor has already
serialised and buys a way to block its executor instead.

## Never block or suspend inside a measurement

No `await`, no semaphore, no synchronous IO, and no lock held across real work.

The reason is where the measurement runs. `Task.detached` — as in `FLLayoutComputer` — leaves the main
actor but **not** the cooperative pool: `detached` means the task inherits no isolation, task-locals or
priority, not that the body runs off-pool. The pool has roughly one thread per core and no reserve, so:

- **CPU-bound work queues.** Text measurement never waits, so it cannot deadlock the pool; it occupies a
  thread and delays unrelated tasks. That is why `FLLayoutComputer` documents itself as a convenience —
  a caller measuring a screenful of cells should use its own queue rather than a detached task per node.
- **Waiting deadlocks it.** A task that blocks holds a thread while making no progress, and a handful of
  them stalls the pool for everything. If a measurement ever must wait, bridge off the pool with
  `withCheckedContinuation` plus `DispatchQueue.global().async` rather than blocking in place.

**Compute outside the lock.** `FLLayoutCache` reads under the lock, measures unlocked, then writes under
the lock — an instance of this rule, and the shape to copy. Its one visible consequence is deliberate:
two concurrent misses on the same key both measure, and the last write wins. The work is pure, so a
duplicate costs time and can never produce a wrong answer, whereas holding the lock across
`node.layout(in:)` would serialise every measurement in the process behind one mutex.

`withLock` takes a non-`async` closure, so the compiler already forbids suspending inside the critical
section. Do not reach for a manual `lock()`/`unlock()` pair to get around it.

## State the reason at every `nonisolated(unsafe)` site

Two shapes are admissible, and each is a `let`:

- **An immutable non-`Sendable` Foundation value stored on a node** — `FLText.attributedText`.
  `NSAttributedString` is not `Sendable`, the node treats it as immutable, and its `hash`/`==` are
  content-based, which is what the cache requires.
- **A `let` built from a literal whose type is only conditionally `Sendable`** — the two `AnyHashable`
  statics in `FLViewRegistry.Constants`, which wrap string literals and are never mutated.

Never annotate a `var`; that is the design being wrong, not the compiler being strict.

**What the annotation does not buy.** `FLText` stores the caller's string by reference without copying,
so an `NSMutableAttributedString` passed in and mutated afterwards breaks the `Sendable` claim *and*
node identity — the hash was taken when the node was built, so a cache entry keyed on it goes stale with
no miss to signal it. Do not add a second node that stores a caller's mutable reference type until that
is closed. The fix is an immutable copy at the boundary, probably cheap because
`NSAttributedString(attributedString:)` shares backing storage, but unmeasured.

## What is pinned, and what is still design

`FLOffMainMeasurementTests` in `Tests/FrameLayoutTests/Runtime/` covers the correctness half:

- a detached task genuinely leaves the main thread
- text and a four-level composite measure identically off-main and on-main, frames included
- `FLLayoutComputer` returns what a direct call returns
- sixty-four concurrent measurements of one node all agree, and of thirty-two distinct nodes do not
  interfere
- a cache probed concurrently for one key ends with one entry and every answer agrees; filled
  concurrently from distinct keys, it keeps all of them
- the two platform calls above

Still design rather than result:

- **No pool-saturation measurement exists.** `Benchmarks/` times a single measurement, never N
  concurrent ones, so the queueing claim above is mechanism rather than a number.
- **The instrument table is reasoned.** Nothing tests that an `actor` would have forced `layout(in:)`
  async; that follows from the protocol being synchronous, and it is worth re-deriving before trusting
  it if `FLNode` ever changes.
- **`FLLayoutCache` still has no suite of its own.** Its concurrent behaviour is covered above and its
  hit-and-miss behaviour by three suites that use it as a tool, but nothing covers `removeAll()` under
  contention.

When you change something in this file's territory that the list above does not cover, you are changing
unpinned behaviour. Add the test with the change, and record any number you take here, as
`node-equality.md` and `layout-proposals.md` both do.
