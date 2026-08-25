import UIKit

public struct FLScrollConfiguration: Sendable, Hashable, WithCustomisable {
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
