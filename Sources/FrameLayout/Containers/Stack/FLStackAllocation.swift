import UIKit

/// Divides a bounded extent among children that cannot all have their ideal size.
public enum FLStackAllocation {
    public static func extents(
        ideals: [CGFloat],
        minimums: [CGFloat],
        isSpacer: [Bool],
        available: CGFloat,
        spacingTotal: CGFloat
    ) -> [CGFloat] {
        let budget = max(0, available - spacingTotal)
        let totalMinimum = minimums.reduce(0, +)

        guard budget > totalMinimum else { return minimums }

        // A spacer never competes for space during a shrink — it holds at its minimum and lets the
        // real content keep what is left.
        let flexibility = ideals.indices.map { index in
            isSpacer[index] ? 0 : max(0, ideals[index] - minimums[index])
        }
        let totalFlexibility = flexibility.reduce(0, +)

        guard totalFlexibility > 0 else { return minimums }

        let slack = budget - totalMinimum

        return ideals.indices.map { index in
            minimums[index] + slack * (flexibility[index] / totalFlexibility)
        }
    }
}
