# File Organisation Rules

Which file a declaration goes in, and what a folder means.

## One file per nameable thing, named after it

A file is called `FLXxx.swift` and the reader can predict what is inside from the name alone. Two
consequences, and both matter more than they sound:

- **Finding a node's view is a filename, not a search.** `FLPadded` is backed by `FLPaddedView`; both
  are in `FLPadded.swift`. Nothing else is.
- **A type you can type at a call site has its own file.** `FLShape`, `FLEdgeInsets`, `FLGridTracks`,
  `FLButtonStyle` are all things a consumer writes, so each is one file.

The test for whether something earns a file: **can a caller construct or name it on its own?** If yes,
it gets a file. If it only ever exists because the type beside it produced it, it stays.

## A node is one thing, not three

`FLPaddedLayout`, `FLPadded` and `FLPaddedView` share a file, and this is the one place the
one-type-per-file rule does not apply. They are not three objects; they are one object in the three
positions of a mutually recursive relation the compiler enforces:

```swift
associatedtype Layout: FLLayout
associatedtype View: FLNodeView where View.Node == Self
```

`FLPaddedView.update(node:layout:)` reads exactly the fields `FLPadded.layout(in:)` wrote, so a change
to a stored property is one edit across all three. Measured over the history: of the last five commits
that touched a node file, four changed two or more of its three types. Splitting them triples the cost
of the common edit and buys nothing, because you never look for `FLPaddedLayout` without already
knowing about `FLPadded`.

The same argument covers three other groupings, and no others:

- `Core/FLNode.swift` — `FLNode`, `FLNodeProviding`, `FLLayout`, `FLNodeView`. The protocol-level
  statement of the same cycle; each fragment is unreadable alone.
- `FLGroup.swift` — `FLGroup` and `FLGroupViews`, for the same reason. A group's `Views` type sits
  with it (`FLConcat` / `FLConcatViews`), exactly as a node's `View` does.
- `FLStackChildren.swift` — `FLStackChild` is built only by `FLGroupChildren.stackChildren` for
  `FLStackChildren` to consume. No caller names it.

`FLAnimationAlways` is a two-line marker type with no meaning apart from `FLAnimated`, and stays with
it. That is the whole exception list; a new one needs the same argument, not a size argument.

## A file leads with its entry point

Whatever a caller reaches for first goes at the top. That resolves differently for the two kinds of
node, and the difference is not cosmetic.

**In `Modifiers/`, the verb leads.** You never name `FLPadded` — `.padding(8)` is the only way in, so
the `FLNodeProviding` extension *is* the file's entry point, and the collapsing overload goes with it
because collapsing is a fact about the verb:

```
public extension FLNodeProviding { padding(_:) … }   // what you type
public extension FLPadded        { padding(_:) … }   // that it collapses rather than wraps
public struct FLPadded           { … }               // what the verb builds
public struct FLPaddedLayout     { … }               // what it measures to
public final class FLPaddedView  { … }               // what renders it
```

**Everywhere else, the type leads.** You write `FLImage(photo)`, `FLText("hi")`,
`FLScroll(.horizontal) { … }` — the initialiser is the entry point, and `resizable()`, `lineLimit(_:)`
and `bounces(_:)` refine a value you already hold. They follow the struct:

```
public struct FLImage      { … }        // what you construct
public extension FLImage   { resizable() … }   // how you refine it
public extension FLImage   { == , hash }
public struct FLImageLayout { … }
public final class FLImageView { … }
```

Hoisting those above the struct inverts the order you actually read them in. They still belong in an
extension rather than interleaved with `layout(in:)` inside the struct — that was the real problem
with `FLImage`, not their position.

**A type's own declarations stay contiguous.** Its extensions sit against the type and the `Layout`
goes after all of them, never between the struct and an extension of it. `FLImage` and `FLGrid` each
have an extension after the struct, so their `Layout` sits immediately before the view.

## A modifier's entry point lives with the node it builds

`padding(_:)` is in `FLPadded.swift`:

```swift
public extension FLNodeProviding {
    func padding(_ insets: FLEdgeInsets) -> FLPadded<ProvidedNode> { … }
}

public extension FLPadded {
    func padding(_ insets: FLEdgeInsets) -> FLPadded<Wrapped> { … }   // collapses
}
```

Both blocks, in that order: the wrapping entry point first, then the collapsing overload on the
concrete wrapper. The collapse rule is a property of the type, so it belongs beside it — see the
modifier notes in `AGENTS.md` for which modifiers collapse and why.

This is the one thing the layout does **not** make discoverable, and the gap is still open. You cannot
find `padding` by browsing filenames, because the file is named after `FLPadded` — nineteen universal
verbs are spread over twelve extension blocks in eleven files, and `background` means two different
things in two of them. Whatever closes it — a documented table, or a single façade file — must not
scatter the entry points themselves into a folder of their own, which would separate a modifier from
the merge rule that defines it.

## A node with companion types gets a folder, named without the prefix

A folder holds one thing and its vocabulary, so opening it shows *things* rather than their parts:

```
Containers/
  Axes/     FLStackAxis FLGridAxis FLVerticalAxis FLHorizontalAxis FLZAxis
  Grid/     FLGrid FLGridItem FLGridTracks FLGridTrack FLGridResolution
  Scroll/   FLScroll FLScrollAxis FLScrollConfiguration FLScrollIdentity FLScrollIndicatorVisibility
  Stack/    FLStack FLStackChildren FLStackGeometry FLStackAllocation
```

Flat, that folder was nineteen files of which three were containers; the rest were grid and stack
vocabulary sitting at the same level as the nodes that own them.

A node with **no** companion types stays a plain file — `Modifiers/FLPadded.swift`, not
`Modifiers/Padded/FLPadded.swift`. A folder holding one file is ceremony.

**Folder names carry no `FL` prefix.** The prefix exists because Swift has no namespaces and a *type*
must be globally unique; a folder is already namespaced by its path, so `Modifiers/FLDecorated/FLDecorated.swift`
stutters without adding information. Every folder is a plain concept noun, which is what `Axes/`,
`Builders/` and `Geometry/` already were.

## What a folder means

| folder | contents |
| --- | --- |
| `Core/` | the vocabulary: the four contract protocols, `FLProposal`, `FLContext`, `FLEnvironment`, and `Geometry/` |
| `Leaves/` | nodes that draw: `FLColor`, `FLText`, `FLImage`, `FLSpacer`, `FLRepresentableNode` |
| `Containers/` | nodes that arrange children, and the axis and resolution types they arrange by |
| `Modifiers/` | nodes that wrap one child, and the value types they carry. `FLAnimated` lives here — `animation(_:)` is an `FLNodeProviding` verb like every other, and a top-level `Animation/` was the one that sat outside |
| `Controls/` | nodes that take input |
| `Group/` | the builder machinery: `FLGroup` and its children at the root, then `Builders/`, `Conditionals/` and `ForEach/` |
| `Composition/` | `FLView` and `FLComposed` — composition as a consumer writes it. Named for what it holds; `View/` read as the home of `FLNodeView`, which lives in `Core/` |
| `Runtime/` | what drives the description: hosting, measurement, caching, the registry, frame application |
| `Support/` | extensions on non-FL types |

A shared type goes in the folder of the thing it serves. When two containers share it — `FLVerticalAxis`
is both an `FLStackAxis` and an `FLGridAxis` — the type and **both** conformances go in one file named
after the type. Splitting the conformances into the two container files is what hid the sharing before.

`Runtime/` is the boundary worth defending: a description type must never import knowledge of it. The
signal that it slipped is a primitive every node view depends on living somewhere else — `flSetFrame`
sat in `Animation/` and made the animation file a dependency of the entire renderer.

## Where this bites

Splitting a file **widens access**. Swift's only implementation-detail scope is the file, so a
`private` member used by a neighbouring type must become `internal` to survive the move. That is a
public-surface change, not a formatting one:

`Optional.filter` in `FLAnimated.swift` is declared `fileprivate` inside a `public extension` and has
one caller. Moving it to `Support/Optional+Extensions.swift` failed to compile, and the fix — making it
`internal` — would have turned a deliberately file-local helper into package-wide API. It stayed.

**When a move needs an access-control change to compile, that is the answer, not an obstacle.** Put it
back and leave it where its scope already says it belongs.
