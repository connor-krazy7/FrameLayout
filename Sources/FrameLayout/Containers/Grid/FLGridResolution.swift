import UIKit

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
