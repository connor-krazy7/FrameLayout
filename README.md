# FrameLayout

Declarative, SwiftUI-shaped content for UIKit, with layout precomputed off the main thread.

You describe a cell the way you would in SwiftUI. The description is a `Sendable`, `Hashable` value, so
its layout can be measured on a background queue, cached, and applied to reused views later — which is
what UIKit collection and table views want, and what SwiftUI cannot give you.

```swift
struct MessageRow: FLView {
    let message: Message

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 8) {
            FLImage(message.avatar)
                .resizable()
                .aspectRatio(1, contentMode: .fit, maxHeight: 32)
                .clipShape(.circle)

            FLVStack(alignment: .leading, spacing: 4) {
                FLText(message.author)
                    .font(.systemFont(ofSize: 13, weight: .semibold))

                FLText(message.text)
                    .lineLimit(4)

                if message.hasFailed {
                    FLButton(tag: Part.retry(message.id)) {
                        FLText("Retry").padding(6)
                    }
                }
            }
        }
        .padding(10)
        .background(.secondarySystemBackground, in: .roundedRectangle(12))
    }
}
```

Measuring and rendering are separate steps, and only the second one touches UIKit:

```swift
let node = MessageRow(message: message).node
let layout = node.layout(in: FLContext(width: availableWidth))   // any queue

host.frame = CGRect(origin: .zero, size: layout.size)            // main actor
host.apply(node: node, layout: layout)
```

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/connor-krazy7/FrameLayout", from: "0.1.0"),
]
```

iOS 17+, Swift 6. UIKit only: every source imports UIKit, so the package builds for iOS and Mac
Catalyst and will not compile for macOS, tvOS, or watchOS.

## How it works

Three parallel type trees, linked by mutually recursive associated types:

| role | protocol | notes |
| --- | --- | --- |
| description | `FLNode` | `Sendable`, `Hashable`; measured off the main thread |
| renderer | `FLNodeView` | `@MainActor` `UIView`, created once per node type and reused |
| geometry | `FLLayout` | precomputed frames, `Equatable`, cacheable |

`FLNode.layout(in:)` is a pure function of `(node, context)`. Nothing in a view's state may influence a
size — that invariant is what buys off-main measurement, so a node never holds closures, handlers, or
view references.

A few consequences worth knowing before using it:

- **A proposal is a question, not a constraint.** A parent offers a size; a child may answer with
  something larger, and the overflow reaches the parent. Only a bounded frame clamps, and it hands its
  resolved box back to the child to lay out in.
- **A cached layout keys on the whole description, so share your colour instances.** Equality is
  synthesised over every stored property, and a `UIColor(dynamicProvider:)` compares equal only to
  itself — nothing about two closures can tell UIKit whether they compute the same thing. So a theme
  colour spelled `static var` hands back a new object on every access, and a cache keyed on a node
  holding it never hits at all, with no diagnostic and nothing in the API suggesting why. Spell it
  `static let`; the system semantic colours are cached singletons and are already safe. Resolving early
  defeats it too — `.label` is a different colour from `.label.resolvedColor(with:)` — so leave
  resolution to the render pass, which reads it from the environment for you.
- **Behaviour is wired by identity, not by closures.** `tag(_:)` names a region, and `FLViewRegistry`
  binds to it — `bindView`, `bindButton`, `bindAction` — so a binding declared once survives a subtree
  disappearing and coming back. A tag names a *region*, so reach the view you want by kind:
  `view(withTag: "filters", as: UIScrollView.self)` to read, `bindView(withTag: "filters", as:)` to
  configure on every apply. What a node declares wins over a binding that fights it.
- **Composites are values.** `FLView` returns a `body`, takes modifiers, and composes in builders; there
  is no view-model layer and no reactive graph.
- **Any UIKit view can be a leaf.** Conform to `FLUIViewRepresentable` with four members. The contract is
  the mirror image of `UIViewRepresentable`: SwiftUI asks the view for its size on the main actor, while
  this asks the *node*, because measurement happens off it.
- **Grids declare one dimension and flow the other.** `FLVGrid(columns:)` breaks rows for you and
  `FLHGrid(rows:)` accumulates columns; a cell is proposed its track's exact extent and nothing along the
  flow, so `aspectRatio(1)` gives squares without dividing widths by hand. Tracks are values —
  `columns: 3`, `.adaptive(minimum: 96)`, `[.fixed(96), .flexible()]` — and each can override the grid's
  gap. Eager, like everything else here.
- **A scroll region is eager and needs bounding.** `FLScroll` measures its content unbounded along the
  axis and takes the extent it was offered, so `frame(maxHeight:)` is what turns it into a viewport;
  offered nothing, it collapses to its content and does not scroll. Every child view is built on apply, so
  it suits a chip row or a sheet body — a feed still wants a `UICollectionView` with an `FLHostView` per
  cell. Scroll position is view state, so a gallery in a reused cell declares where each content starts:

  ```swift
  FLScroll(.horizontal) { … }
      .initialContentOffset(offsets[album.id] ?? .zero, contentID: album.id)
  ```

  Applied once per content — a new album starts where you say, dragging survives a re-apply that only
  changed data, and returning to an album restores it. Without a `contentID:` it is applied once for the
  view, which is only safe where the host is not recycled.

## Layout of the repository

| path | contents |
| --- | --- |
| `Sources/FrameLayout/` | the framework |
| `Tests/FrameLayoutTests/` | its tests, benchmarks, and fixtures |
| `Examples/Playgrounds.xcodeproj` | a demo app of playgrounds and SwiftUI-comparison previews |

`FrameLayout.xcworkspace` opens both together.

## Development

```sh
make test              # both suites
make test-package
make test-examples
make build-package     # no app, no simulator boot
make test SIMULATOR="iPhone 16 Pro"
```

Behaviour is checked against real SwiftUI where the two systems should agree: `FLSwiftUIParityTests`
measures FL's computed sizes against `UIHostingController.sizeThatFits(in:)`, and renders with
`ImageRenderer` to compare where a child actually landed.

## Status

A prototype. The API still moves, and it exists to answer a specific question — whether conversation
cells are better described as composition than as hand-nested initialisers.

## License

MIT. See [LICENSE](LICENSE).
