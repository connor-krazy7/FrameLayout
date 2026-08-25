import UIKit

public struct FLGridItem: Sendable, Hashable {
    public enum Size: Sendable, Hashable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat, maximum: CGFloat)
        case adaptive(minimum: CGFloat, maximum: CGFloat)
    }

    public var size: Size
    public var spacing: CGFloat?
    public var alignment: FLAlignment?

    public init(_ size: Size, spacing: CGFloat? = nil, alignment: FLAlignment? = nil) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }

    public static func fixed(
        _ extent: CGFloat,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.fixed(extent), spacing: spacing, alignment: alignment)
    }

    public static func flexible(
        minimum: CGFloat = 0,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.flexible(minimum: minimum, maximum: maximum), spacing: spacing, alignment: alignment)
    }

    public static func adaptive(
        minimum: CGFloat,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil,
        alignment: FLAlignment? = nil
    ) -> FLGridItem {
        FLGridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing, alignment: alignment)
    }
}

public struct FLGridTracks: Sendable, Hashable, ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral {
    public let items: [FLGridItem]

    public init(_ items: [FLGridItem]) {
        self.items = items
    }

    public init(integerLiteral count: Int) {
        items = Array(repeating: FLGridItem.flexible(), count: Swift.max(1, count))
    }

    public init(arrayLiteral elements: FLGridItem...) {
        items = elements
    }

    public static func fixed(_ extent: CGFloat, spacing: CGFloat? = nil) -> FLGridTracks {
        FLGridTracks([.fixed(extent, spacing: spacing)])
    }

    public static func flexible(
        minimum: CGFloat = 0,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil
    ) -> FLGridTracks {
        FLGridTracks([.flexible(minimum: minimum, maximum: maximum, spacing: spacing)])
    }

    public static func adaptive(
        minimum: CGFloat,
        maximum: CGFloat = .infinity,
        spacing: CGFloat? = nil
    ) -> FLGridTracks {
        FLGridTracks([.adaptive(minimum: minimum, maximum: maximum, spacing: spacing)])
    }
}

/// What a grid needs from its orientation. Separate from `FLStackAxis` because a grid has two live axes:
/// the one whose tracks are declared, and the one lines accumulate along.
public protocol FLGridAxis: Sendable {
    static var gridToken: String { get }

    static func flowExtent(of size: CGSize) -> CGFloat
    static func crossExtent(of size: CGSize) -> CGFloat
    static func crossProposal(in context: FLContext) -> FLProposal
    static func size(flow: CGFloat, cross: CGFloat) -> CGSize
    static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint
    static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext
}

extension FLVerticalAxis: FLGridAxis {
    public static var gridToken: String { "vgrid" }

    public static func flowExtent(of size: CGSize) -> CGFloat { size.height }
    public static func crossExtent(of size: CGSize) -> CGFloat { size.width }
    public static func crossProposal(in context: FLContext) -> FLProposal { context.width }
    public static func size(flow: CGFloat, cross: CGFloat) -> CGSize { CGSize(width: cross, height: flow) }
    public static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint { CGPoint(x: cross, y: flow) }

    public static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext {
        context.proposing(width: .exact(cross), height: .unspecified)
    }
}

extension FLHorizontalAxis: FLGridAxis {
    public static var gridToken: String { "hgrid" }

    public static func flowExtent(of size: CGSize) -> CGFloat { size.width }
    public static func crossExtent(of size: CGSize) -> CGFloat { size.height }
    public static func crossProposal(in context: FLContext) -> FLProposal { context.height }
    public static func size(flow: CGFloat, cross: CGFloat) -> CGSize { CGSize(width: flow, height: cross) }
    public static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint { CGPoint(x: flow, y: cross) }

    public static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext {
        context.proposing(width: .unspecified, height: .exact(cross))
    }
}

public struct FLGridTrack: Sendable, Equatable {
    public let extent: CGFloat
    public let spacingAfter: CGFloat
    public let alignment: FLAlignment?
}

public enum FLGridResolution {
    /// Fixed tracks take their extent, adaptive ones repeat as often as they fit, and what is left is shared
    /// between flexible and adaptive tracks. With no extent offered, every flexible track collapses to its
    /// minimum — there is nothing to share.
    public static func tracks(
        _ tracks: FLGridTracks,
        available: CGFloat?,
        spacing: CGFloat
    ) -> [FLGridTrack] {
        let expanded = expand(tracks, available: available, spacing: spacing)

        guard !expanded.isEmpty else { return [] }

        let gaps = expanded.dropLast().reduce(CGFloat(0)) { $0 + ($1.spacing.or(spacing)) }
        let fixedTotal = expanded.reduce(CGFloat(0)) { total, item in
            guard case let .fixed(extent) = item.size else { return total }

            return total + extent
        }
        let shareCount = expanded.filter { if case .fixed = $0.size { false } else { true } }.count
        let remaining = available.map { Swift.max(0, $0 - fixedTotal - gaps) }.or(0)
        let share = shareCount > 0 ? remaining / CGFloat(shareCount) : 0

        return expanded.indices.map { index in
            let item = expanded[index]

            return FLGridTrack(
                extent: extent(of: item, share: share),
                spacingAfter: index == expanded.count - 1 ? 0 : item.spacing.or(spacing),
                alignment: item.alignment
            )
        }
    }

    private static func expand(
        _ tracks: FLGridTracks,
        available: CGFloat?,
        spacing: CGFloat
    ) -> [FLGridItem] {
        tracks.items.flatMap { item -> [FLGridItem] in
            guard case let .adaptive(minimum, maximum) = item.size, let available, minimum > 0 else {
                return [item]
            }

            let gap = item.spacing.or(spacing)
            let count = Swift.max(1, Int((available + gap) / (minimum + gap)))

            return Array(
                repeating: FLGridItem(
                    .flexible(minimum: minimum, maximum: maximum),
                    spacing: item.spacing,
                    alignment: item.alignment
                ),
                count: count
            )
        }
    }

    private static func extent(of item: FLGridItem, share: CGFloat) -> CGFloat {
        switch item.size {
        case let .fixed(extent):
            extent
        case let .flexible(minimum, maximum), let .adaptive(minimum, maximum):
            Swift.min(Swift.max(share, minimum), maximum)
        }
    }
}

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
