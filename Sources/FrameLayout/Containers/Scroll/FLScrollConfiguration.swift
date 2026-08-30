import UIKit

public struct FLScrollConfiguration: Sendable, FLLayoutEquatable, WithCustomisable {
    public var contentID: FLScrollIdentity?
    public var initialContentOffset: CGPoint = .zero
    public var indicators: FLScrollIndicatorVisibility = .automatic
    public var contentInsets: FLEdgeInsets = .zero
    public var isScrollDisabled = false
    public var bounces = true
    public var isPagingEnabled = false
    public var keyboardDismissMode: UIScrollView.KeyboardDismissMode = .none
    public var contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior = .never
}

// MARK: - FLLayoutEquatable

public extension FLScrollConfiguration {
    /// No field here is read by `FLScroll.layout(in:)`; every one is applied to the `UIScrollView` at
    /// update.
    func isLayoutEquivalent(to other: FLScrollConfiguration) -> Bool { true }

    func hashLayoutIdentity(into hasher: inout Hasher) {}
}
