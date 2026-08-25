import UIKit

public struct FLGridLayout: FLLayout {
    public let children: FLGroupChildren
    public let childFrames: [CGRect]
    public let size: CGSize
}

public struct FLGrid<Axis: FLGridAxis, Group: FLGroup>: FLNode {
    public typealias View = FLGridView<Axis, Group>

    public static var typeIdentifier: String { "\(Axis.gridToken)(\(Group.typeIdentifier))" }

    public let tracks: FLGridTracks
    public let flowSpacing: CGFloat
    public let crossSpacing: CGFloat
    public let alignment: FLAlignment
    public let group: Group

    init(
        tracks: FLGridTracks,
        flowSpacing: CGFloat,
        crossSpacing: CGFloat,
        alignment: FLAlignment,
        group: Group
    ) {
        self.tracks = tracks
        self.flowSpacing = flowSpacing
        self.crossSpacing = crossSpacing
        self.alignment = alignment
        self.group = group
    }

    public func layout(in context: FLContext) -> FLGridLayout {
        let resolved = FLGridResolution.tracks(
            tracks,
            available: Axis.crossProposal(in: context).exactValue,
            spacing: crossSpacing
        )

        guard !resolved.isEmpty, group.childCount > 0 else {
            return FLGridLayout(children: group.layout(in: context), childFrames: [], size: .zero)
        }

        let contexts = (0..<group.childCount).map { index in
            Axis.childContext(context, cross: resolved[index % resolved.count].extent)
        }
        let children = group.layout(childContexts: contexts[...])
        let flowExtents = children.sizes.map(Axis.flowExtent(of:))
        let lines = stride(from: 0, to: flowExtents.count, by: resolved.count).map { start in
            flowExtents[start..<Swift.min(start + resolved.count, flowExtents.count)].max().or(0)
        }
        let crossOffsets = offsets(of: resolved)
        let flowOffsets = offsets(ofLines: lines)

        return FLGridLayout(
            children: children,
            childFrames: children.sizes.indices.map { index in
                frame(
                    at: index,
                    childSize: children.sizes[index],
                    tracks: resolved,
                    lines: lines,
                    crossOffsets: crossOffsets,
                    flowOffsets: flowOffsets,
                    direction: context.layoutDirection
                )
            },
            size: Axis.size(
                flow: lines.reduce(0, +) + CGFloat(Swift.max(0, lines.count - 1)) * flowSpacing,
                cross: resolved.reduce(CGFloat(0)) { $0 + $1.extent + $1.spacingAfter }
            )
        )
    }

    private func frame(
        at index: Int,
        childSize: CGSize,
        tracks: [FLGridTrack],
        lines: [CGFloat],
        crossOffsets: [CGFloat],
        flowOffsets: [CGFloat],
        direction: FLLayoutDirection
    ) -> CGRect {
        let column = index % tracks.count
        let line = index / tracks.count
        let cell = Axis.size(flow: lines[line], cross: tracks[column].extent)
        let inCell = tracks[column].alignment.or(alignment).origin(
            childSize: childSize,
            containerSize: cell,
            direction: direction
        )
        let cellOrigin = Axis.origin(flow: flowOffsets[line], cross: crossOffsets[column])

        return CGRect(
            origin: CGPoint(x: cellOrigin.x + inCell.x, y: cellOrigin.y + inCell.y),
            size: childSize
        )
    }

    private func offsets(of tracks: [FLGridTrack]) -> [CGFloat] {
        tracks.indices.reduce(into: [CGFloat]()) { offsets, index in
            let previous = offsets.last.or(0)
            let gap = index == 0 ? 0 : tracks[index - 1].extent + tracks[index - 1].spacingAfter

            offsets.append(previous + gap)
        }
    }

    private func offsets(ofLines lines: [CGFloat]) -> [CGFloat] {
        lines.indices.reduce(into: [CGFloat]()) { offsets, index in
            let previous = offsets.last.or(0)
            let gap = index == 0 ? 0 : lines[index - 1] + flowSpacing

            offsets.append(previous + gap)
        }
    }
}

public typealias FLVGrid<Group: FLGroup> = FLGrid<FLVerticalAxis, Group>
public typealias FLHGrid<Group: FLGroup> = FLGrid<FLHorizontalAxis, Group>

public extension FLGrid where Axis == FLVerticalAxis {
    init(
        columns: FLGridTracks,
        spacing: CGFloat = 0,
        alignment: FLAlignment = .center,
        @FLGroupBuilder content: () -> Group
    ) {
        self.init(
            tracks: columns,
            flowSpacing: spacing,
            crossSpacing: spacing,
            alignment: alignment,
            group: content()
        )
    }

    init(
        columns: FLGridTracks,
        rowSpacing: CGFloat = 0,
        columnSpacing: CGFloat = 0,
        alignment: FLAlignment = .center,
        @FLGroupBuilder content: () -> Group
    ) {
        self.init(
            tracks: columns,
            flowSpacing: rowSpacing,
            crossSpacing: columnSpacing,
            alignment: alignment,
            group: content()
        )
    }
}

public extension FLGrid where Axis == FLHorizontalAxis {
    init(
        rows: FLGridTracks,
        spacing: CGFloat = 0,
        alignment: FLAlignment = .center,
        @FLGroupBuilder content: () -> Group
    ) {
        self.init(
            tracks: rows,
            flowSpacing: spacing,
            crossSpacing: spacing,
            alignment: alignment,
            group: content()
        )
    }

    init(
        rows: FLGridTracks,
        rowSpacing: CGFloat = 0,
        columnSpacing: CGFloat = 0,
        alignment: FLAlignment = .center,
        @FLGroupBuilder content: () -> Group
    ) {
        self.init(
            tracks: rows,
            flowSpacing: columnSpacing,
            crossSpacing: rowSpacing,
            alignment: alignment,
            group: content()
        )
    }
}

public final class FLGridView<Axis: FLGridAxis, Group: FLGroup>: FLStructuralView, FLNodeView {
    public typealias Node = FLGrid<Axis, Group>

    private let groupViews = Group.Views()

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLGrid<Axis, Group>, layout: FLGridLayout, context: FLRenderContext) {
        let childViews = groupViews.update(group: node.group, children: layout.children, context: context)

        for (childView, childFrame) in zip(childViews, layout.childFrames) {
            if childView.superview !== self {
                addSubview(childView)
            }

            childView.flSetFrame(childFrame, in: context)
        }
    }
}
