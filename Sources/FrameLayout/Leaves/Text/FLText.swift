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
        return text(
            withDefaults: [
                .font: resolved.font.or(Self.defaultFont),
                .foregroundColor: resolved.foregroundColor.or(Self.defaultColor),
            ]
        )
    }

    func measuredText(in environment: FLEnvironment) -> NSAttributedString {
        let resolved = environment.applying(overrides)
        return text(withDefaults: [.font: resolved.font.or(Self.defaultFont)])
    }

    private func text(withDefaults attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard attributedText.underlying.length > 0 else { return attributedText.underlying }

        let filled = NSMutableAttributedString(attributedString: attributedText.underlying)

        for (key, value) in attributes {
            Self.fillGaps(of: key, with: value, in: filled)
        }

        return filled
    }

    private static func fillGaps(
        of key: NSAttributedString.Key,
        with value: Any,
        in target: NSMutableAttributedString
    ) {
        let fullRange = NSRange(location: 0, length: target.length)

        var missing: [NSRange] = []
        target.enumerateAttribute(key, in: fullRange, options: []) { existing, subrange, _ in
            guard existing == nil else { return }
            missing.append(subrange)
        }

        for subrange in missing {
            target.addAttribute(key, value: value, range: subrange)
        }
    }

    public func layout(in context: FLContext) -> FLTextLayout {
        let text = measuredText(in: context.environment)

        guard text.length > 0 else { return FLTextLayout(size: .zero) }

        let availableWidth = measurementWidth(for: context.width, attributedText: text)

        guard availableWidth > 0 else { return FLTextLayout(size: .zero) }

        let storage = NSTextStorage(attributedString: text)
        let container = NSTextContainer(
            size: CGSize(
                width: availableWidth,
                height: context.height.exactValue.or(.greatestFiniteMagnitude)
            )
        ).then {
            $0.lineFragmentPadding = 0
            $0.maximumNumberOfLines = lineLimit
            $0.lineBreakMode = lineBreakMode
        }
        let manager = NSLayoutManager()

        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)

        let used = manager.usedRect(for: container)

        return FLTextLayout(
            size: CGSize(
                width: context.clampingWidth(ceil(used.width)),
                height: context.clampingHeight(ceil(used.height))
            )
        )
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

// MARK: - Helpers

private extension FLText {
    func measurementWidth(for proposal: FLProposal, attributedText: NSAttributedString) -> CGFloat {
        switch proposal {
        case .unspecified, .maximum: .greatestFiniteMagnitude
        case .minimum: Self.minimumWidth(of: attributedText)
        case let .exact(value): value
        }
    }

    // TextKit cannot be asked for an intrinsic minimum: a zero-width container is treated as
    // unbounded, and any small width simply wraps inside words. So the minimum is a policy — the
    // widest run that cannot be broken — and here that policy is "break only at whitespace".
    //
    // Hyphens and other break opportunities are not considered, so this can over-report. That is the
    // safe direction: an over-large minimum makes a container refuse to squeeze text further than it
    // should, where an under-report would let it wrap into something unreadable.
    static func minimumWidth(of attributedText: NSAttributedString) -> CGFloat {
        let string = attributedText.string as NSString
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        var widest: CGFloat = 0
        var searchStart = 0

        while searchStart < string.length {
            let remaining = NSRange(location: searchStart, length: string.length - searchStart)
            let separator = string.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: remaining)

            let runRange: NSRange
            if separator.location == NSNotFound {
                runRange = remaining
                searchStart = string.length
            } else {
                runRange = NSRange(location: searchStart, length: separator.location - searchStart)
                searchStart = separator.location + separator.length
            }

            guard runRange.length > 0 else { continue }

            let bounds = attributedText
                .attributedSubstring(from: runRange)
                .boundingRect(with: unbounded, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            widest = Swift.max(widest, ceil(bounds.width))
        }

        return widest
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
