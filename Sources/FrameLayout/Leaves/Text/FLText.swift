import UIKit

// MARK: - Node

public struct FLText: FLNode {
    public typealias View = FLTextView

    /// Matches `UILabel`'s own defaults, so an unstyled `FLText` renders the same as an unstyled label.
    public static var defaultFont: UIFont { .systemFont(ofSize: UIFont.labelFontSize) }
    public static var defaultColor: UIColor { .label }

    /// Always stored attributed. Plain text is simply an attributed string with no attributes, which
    /// is what lets styling be filled in later from the environment.
    public let attributedText: FLAttributedString
    public let lineLimit: Int
    public let lineBreakMode: NSLineBreakMode
    /// Styling set directly on this text. Unset fields inherit from the environment.
    public let overrides: FLEnvironmentOverrides

    public init(
        _ attributedText: FLAttributedString,
        lineLimit: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.init(
            attributedText: attributedText,
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode,
            overrides: FLEnvironmentOverrides()
        )
    }

    public init(
        _ attributedText: NSAttributedString,
        lineLimit: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.init(
            FLAttributedString(attributedText),
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode
        )
    }

    public init(
        _ attributedText: AttributedString,
        lineLimit: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.init(
            FLAttributedString(attributedText),
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode
        )
    }

    public init(
        _ string: String,
        lineLimit: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.init(
            FLAttributedString(string),
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode
        )
    }

    private init(
        attributedText: FLAttributedString,
        lineLimit: Int,
        lineBreakMode: NSLineBreakMode,
        overrides: FLEnvironmentOverrides
    ) {
        self.attributedText = attributedText
        self.lineLimit = lineLimit
        self.lineBreakMode = lineBreakMode
        self.overrides = overrides
    }

    /// Precedence: attributes already on the string, then this text's styling, then the environment,
    /// then the defaults. Rendering only — `layout(in:)` measures `measuredText(in:)`.
    public func resolvedText(in environment: FLEnvironment) -> NSAttributedString {
        let resolved = environment.applying(overrides)
        return attributedText.text(
            withDefaults: [
                .font: resolved.font.or(Self.defaultFont),
                .foregroundColor: resolved.foregroundColor.or(Self.defaultColor),
            ]
        )
    }

    func measuredText(in environment: FLEnvironment) -> NSAttributedString {
        let resolved = environment.applying(overrides)
        return attributedText.text(withDefaults: [.font: resolved.font.or(Self.defaultFont)])
    }

    public func layout(in context: FLContext) -> FLTextLayout {
        let measurement = FLTextMeasurement(
            attributedText: measuredText(in: context.environment),
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode
        )

        return FLTextLayout(size: measurement.size(in: context))
    }
}

// MARK: - FLLayoutEquatable

public extension FLText {
    func isLayoutEquivalent(to other: FLText) -> Bool {
        lineLimit == other.lineLimit
            && lineBreakMode == other.lineBreakMode
            && attributedText.isLayoutEquivalent(to: other.attributedText)
            && overrides.isLayoutEquivalent(to: other.overrides)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(lineLimit)
        hasher.combine(lineBreakMode)
        attributedText.hashLayoutIdentity(into: &hasher)
        overrides.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - Modifiers

public extension FLText {
    func lineLimit(_ limit: Int) -> FLText {
        FLText(
            attributedText: attributedText,
            lineLimit: max(0, limit),
            lineBreakMode: lineBreakMode,
            overrides: overrides
        )
    }

    func lineBreakMode(_ mode: NSLineBreakMode) -> FLText {
        FLText(
            attributedText: attributedText,
            lineLimit: lineLimit,
            lineBreakMode: mode,
            overrides: overrides
        )
    }

    // These shadow the FLNode versions for FLText, the way SwiftUI's `Text.font(_:) -> Text` shadows
    // `View.font(_:) -> some View`. Keeping the type means text modifiers still chain afterwards.
    func font(_ font: UIFont?) -> FLText {
        environment(FLEnvironmentOverrides(font: font))
    }

    func foregroundColor(_ color: UIColor?) -> FLText {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func environment(_ other: FLEnvironmentOverrides) -> FLText {
        FLText(
            attributedText: attributedText,
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode,
            overrides: overrides.merging(other)
        )
    }

    /// Writes alignment into the stored string's paragraph style, leaving font and colour absent so
    /// they still inherit.
    func multilineTextAlignment(_ alignment: NSTextAlignment) -> FLText {
        let mutable = NSMutableAttributedString(attributedString: attributedText.underlying)
        let fullRange = NSRange(location: 0, length: mutable.length)

        var pendingStyles: [(NSRange, NSMutableParagraphStyle)] = []
        mutable.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            let existing = value as? NSParagraphStyle
            let style = (existing?.mutableCopy() as? NSMutableParagraphStyle)
                .or(NSMutableParagraphStyle())
                .then { $0.alignment = alignment }
            pendingStyles.append((range, style))
        }

        for (range, style) in pendingStyles {
            mutable.addAttribute(.paragraphStyle, value: style, range: range)
        }

        return FLText(
            attributedText: FLAttributedString(mutable),
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode,
            overrides: overrides
        )
    }
}

// MARK: - Layout

public struct FLTextLayout: FLLayout {
    public let size: CGSize
}

// MARK: - View

public final class FLTextView: UILabel, FLNodeView {
    public typealias Node = FLText

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLText, layout: FLTextLayout, context: FLRenderContext) {
        numberOfLines = node.lineLimit
        lineBreakMode = node.lineBreakMode
        attributedText = node.resolvedText(in: context.environment)
    }
}
