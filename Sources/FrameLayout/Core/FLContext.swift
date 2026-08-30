import UIKit

public struct FLContext: Sendable, FLLayoutEquatable, WithCustomisable {
    public var width: FLProposal
    public var height: FLProposal
    public var environment: FLEnvironment

    public var layoutDirection: FLLayoutDirection { environment.layoutDirection }
    public var contentSizeCategory: String { environment.contentSizeCategory }

    public init(
        width: FLProposal = .unspecified,
        height: FLProposal = .unspecified,
        layoutDirection: FLLayoutDirection = .leftToRight,
        contentSizeCategory: String = UIContentSizeCategory.large.rawValue,
        environment: FLEnvironment? = nil
    ) {
        self.width = width
        self.height = height
        self.environment = environment.or(
            FLEnvironment(layoutDirection: layoutDirection, contentSizeCategory: contentSizeCategory)
        )
    }

    public init(
        width: CGFloat?,
        height: CGFloat? = nil,
        layoutDirection: FLLayoutDirection = .leftToRight,
        contentSizeCategory: String = UIContentSizeCategory.large.rawValue,
        environment: FLEnvironment? = nil
    ) {
        self.init(
            width: width.map(FLProposal.exact).or(.unspecified),
            height: height.map(FLProposal.exact).or(.unspecified),
            layoutDirection: layoutDirection,
            contentSizeCategory: contentSizeCategory,
            environment: environment
        )
    }

    public func applying(_ overrides: FLEnvironmentOverrides) -> FLContext {
        with { $0.environment = $0.environment.applying(overrides) }
    }

    public static var unspecified: FLContext { FLContext() }

    public func proposing(width newWidth: FLProposal, height newHeight: FLProposal) -> FLContext {
        with {
            $0.width = newWidth
            $0.height = newHeight
        }
    }

    public func inset(by insets: FLEdgeInsets) -> FLContext {
        proposing(
            width: width.inset(by: insets.horizontal),
            height: height.inset(by: insets.vertical)
        )
    }

    /// Narrows a computed extent to the proposal, which only bounds it when the proposal is exact.
    public func clampingWidth(_ proposedWidth: CGFloat) -> CGFloat {
        width.exactValue.map { Swift.min($0, proposedWidth) }.or(proposedWidth)
    }

    public func clampingHeight(_ proposedHeight: CGFloat) -> CGFloat {
        height.exactValue.map { Swift.min($0, proposedHeight) }.or(proposedHeight)
    }
}

// MARK: - FLLayoutEquatable

public extension FLContext {
    func isLayoutEquivalent(to other: FLContext) -> Bool {
        width == other.width
            && height == other.height
            && environment.isLayoutEquivalent(to: other.environment)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        environment.hashLayoutIdentity(into: &hasher)
    }
}
