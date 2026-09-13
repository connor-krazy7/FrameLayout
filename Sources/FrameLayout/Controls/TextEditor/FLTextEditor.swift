import UIKit

// MARK: - Node

/// Typed text is view state and `layout(in:)` is a pure function of the node, so the editor never grows
/// itself: it keeps the frame the layout reserved, and scrolls inside it or clips. A height that follows
/// the text is the caller's loop — the delegate reports the change, and a new node re-measures the frame
/// around text the editor already holds.
///
/// That loop makes every keystroke a new cache key, and `FLLayoutCache` is unbounded and only ever keyed
/// at the root: keep an editing root out of a cache, or clear it when editing ends.
///
/// Bind a `UITextView` under this node's tag to reach it. Assigning its `delegate` adds a forwarding
/// target rather than replacing the editor's own, so every `UITextViewDelegate` method is yours without
/// the editor losing the callbacks it needs.
public struct FLTextEditor: FLNode {
    public typealias View = FLTextEditorView

    /// What the editor starts with, and what `layout(in:)` measures. Seeded on the first apply and again
    /// only when `contentID` changes, so typing survives a re-render the caller did not drive. In a
    /// reused cell pass a `contentID(_:)`, or a recycled editor keeps what the previous item left behind.
    public let initialText: FLAttributedString
    /// Drawn while the editor is empty; never measured, so it cannot change a frame.
    public let placeholder: FLAttributedString?
    /// Styling set directly on this editor. Unset fields inherit from the environment.
    public let overrides: FLEnvironmentOverrides
    public let configuration: FLTextEditorConfiguration

    public init(_ initialText: FLAttributedString, placeholder: FLAttributedString? = nil) {
        self.init(
            initialText: initialText,
            placeholder: placeholder,
            overrides: FLEnvironmentOverrides(),
            configuration: FLTextEditorConfiguration()
        )
    }

    public init(_ string: String, placeholder: String? = nil) {
        self.init(FLAttributedString(string), placeholder: placeholder.map(FLAttributedString.init))
    }

    private init(
        initialText: FLAttributedString,
        placeholder: FLAttributedString?,
        overrides: FLEnvironmentOverrides,
        configuration: FLTextEditorConfiguration
    ) {
        self.initialText = initialText
        self.placeholder = placeholder
        self.overrides = overrides
        self.configuration = configuration
    }

    /// Precedence: attributes already on the string, then this editor's styling, then the environment,
    /// then the defaults. Rendering only — `layout(in:)` measures `measuredText(in:)`.
    public func resolvedText(in environment: FLEnvironment) -> NSAttributedString {
        initialText.text(
            withDefaults: [
                .font: resolvedFont(in: environment),
                .foregroundColor: resolvedColor(in: environment),
            ]
        )
    }

    func measuredText(in environment: FLEnvironment) -> NSAttributedString {
        initialText.text(withDefaults: [.font: resolvedFont(in: environment)])
    }

    /// Takes the editor's font, and `.placeholderText` unless the string names its own colour.
    public func resolvedPlaceholder(in environment: FLEnvironment) -> NSAttributedString? {
        placeholder?.text(
            withDefaults: [
                .font: resolvedFont(in: environment),
                .foregroundColor: UIColor.placeholderText,
            ]
        )
    }

    public func resolvedFont(in environment: FLEnvironment) -> UIFont {
        environment.applying(overrides).font.or(FLText.defaultFont)
    }

    public func resolvedColor(in environment: FLEnvironment) -> UIColor {
        environment.applying(overrides).foregroundColor.or(FLText.defaultColor)
    }

    public func layout(in context: FLContext) -> FLTextEditorLayout {
        let insets = configuration.textContainerInset
        let measurement = FLTextMeasurement(
            attributedText: measuredText(in: context.environment),
            lineLimit: 0,
            lineBreakMode: .byWordWrapping
        )
        let text = measurement.size(in: context.inset(by: insets))

        // An empty editor is still a target to tap and a caret to place, so it reserves one line rather
        // than the zero an empty string measures to.
        let content = Swift.max(text.height, ceil(resolvedFont(in: context.environment).lineHeight))
        let height = content + insets.vertical

        let hugged = text.width + insets.horizontal

        return FLTextEditorLayout(
            size: CGSize(
                width: configuration.isEditable
                    ? context.width.resolved(ideal: hugged)
                    : context.clampingWidth(hugged),
                height: configuration.isEditable
                    ? context.height.resolved(ideal: height)
                    : context.clampingHeight(height)
            )
        )
    }
}

// MARK: - Modifiers

public extension FLTextEditor {
    func placeholder(_ placeholder: FLAttributedString?) -> FLTextEditor {
        FLTextEditor(
            initialText: initialText,
            placeholder: placeholder,
            overrides: overrides,
            configuration: configuration
        )
    }

    func placeholder(_ placeholder: String) -> FLTextEditor {
        self.placeholder(FLAttributedString(placeholder))
    }

    // These shadow the `FLNode` versions, as `FLText`'s do, so editor modifiers still chain afterwards.
    func font(_ font: UIFont?) -> FLTextEditor {
        environment(FLEnvironmentOverrides(font: font))
    }

    func foregroundColor(_ color: UIColor?) -> FLTextEditor {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func environment(_ other: FLEnvironmentOverrides) -> FLTextEditor {
        FLTextEditor(
            initialText: initialText,
            placeholder: placeholder,
            overrides: overrides.merging(other),
            configuration: configuration
        )
    }

    /// Names the content being edited, so a new item re-seeds `initialText`.
    func contentID(_ id: some Hashable & Sendable) -> FLTextEditor {
        configured { $0.contentID = FLContentIdentity(id) }
    }

    func textContainerInset(_ insets: FLEdgeInsets) -> FLTextEditor {
        configured { $0.textContainerInset = insets }
    }

    func scrollEnabled(_ isEnabled: Bool = true) -> FLTextEditor {
        configured { $0.isScrollEnabled = isEnabled }
    }

    func editable(_ isEditable: Bool = true) -> FLTextEditor {
        configured { $0.isEditable = isEditable }
    }

    func selectable(_ isSelectable: Bool = true) -> FLTextEditor {
        configured { $0.isSelectable = isSelectable }
    }

    func clearsOnInsertion(_ clears: Bool = true) -> FLTextEditor {
        configured { $0.clearsOnInsertion = clears }
    }

    func scrollIndicators(_ isVisible: Bool) -> FLTextEditor {
        configured { $0.showsIndicators = isVisible }
    }

    func keyboardType(_ type: UIKeyboardType) -> FLTextEditor {
        configured { $0.keyboardType = type }
    }

    func returnKeyType(_ type: UIReturnKeyType) -> FLTextEditor {
        configured { $0.returnKeyType = type }
    }

    func keyboardAppearance(_ appearance: UIKeyboardAppearance) -> FLTextEditor {
        configured { $0.keyboardAppearance = appearance }
    }

    func autocapitalization(_ type: UITextAutocapitalizationType) -> FLTextEditor {
        configured { $0.autocapitalizationType = type }
    }

    func autocorrection(_ type: UITextAutocorrectionType) -> FLTextEditor {
        configured { $0.autocorrectionType = type }
    }

    func spellChecking(_ type: UITextSpellCheckingType) -> FLTextEditor {
        configured { $0.spellCheckingType = type }
    }

    func textContentType(_ type: UITextContentType?) -> FLTextEditor {
        configured { $0.textContentType = type }
    }

    func dataDetectorTypes(_ types: UIDataDetectorTypes) -> FLTextEditor {
        configured { $0.dataDetectorTypes = types }
    }

    func caretColor(_ color: UIColor?) -> FLTextEditor {
        configured { $0.caretColor = color }
    }

    private func configured(_ transform: (inout FLTextEditorConfiguration) -> Void) -> FLTextEditor {
        FLTextEditor(
            initialText: initialText,
            placeholder: placeholder,
            overrides: overrides,
            configuration: configuration.with(transform)
        )
    }
}

// MARK: - FLLayoutEquatable

public extension FLTextEditor {
    /// `placeholder` is absent on purpose: it is drawn and never measured.
    func isLayoutEquivalent(to other: FLTextEditor) -> Bool {
        initialText.isLayoutEquivalent(to: other.initialText)
            && overrides.isLayoutEquivalent(to: other.overrides)
            && configuration.isLayoutEquivalent(to: other.configuration)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        initialText.hashLayoutIdentity(into: &hasher)
        overrides.hashLayoutIdentity(into: &hasher)
        configuration.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - Layout

public struct FLTextEditorLayout: FLLayout {
    public let size: CGSize
}

// MARK: - View

public final class FLTextEditorView: UIView, FLNodeView {
    public typealias Node = FLTextEditor

    private let input = FLTextEditorInput()
    private var applied: AppliedContent?

    public override init(frame: CGRect) {
        super.init(frame: frame)

        input.backgroundColor = .clear
        input.contentInsetAdjustmentBehavior = .never
        addSubview(input)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        input.frame = bounds
    }

    public func update(node: FLTextEditor, layout: FLTextEditorLayout, context: FLRenderContext) {
        let environment = context.environment
        let current = AppliedContent(
            contentID: node.configuration.contentID,
            style: AppliedContent.Style(
                font: node.resolvedFont(in: environment),
                color: node.resolvedColor(in: environment)
            )
        )

        apply(node.configuration, isEnabled: context.isEnabled, direction: environment.layoutDirection)
        seedText(node: node, environment: environment)
        restyle(to: current.style)
        // After the seed, never before: assigning `attributedText` replaces `typingAttributes`.
        input.typingAttributes = [.font: current.style.font, .foregroundColor: current.style.color]
        input.attributedPlaceholder = node.resolvedPlaceholder(in: environment)
        input.accessibilityLabel = context.accessibilityLabel
        applied = current
    }

    private func apply(
        _ configuration: FLTextEditorConfiguration,
        isEnabled: Bool,
        direction: FLLayoutDirection
    ) {
        isUserInteractionEnabled = isEnabled

        input.isEditable = configuration.isEditable
        input.isSelectable = configuration.isSelectable
        input.isScrollEnabled = configuration.isScrollEnabled
        input.showsVerticalScrollIndicator = configuration.showsIndicators
        input.clearsOnInsertion = configuration.clearsOnInsertion
        input.keyboardType = configuration.keyboardType
        input.returnKeyType = configuration.returnKeyType
        input.keyboardAppearance = configuration.keyboardAppearance
        input.autocapitalizationType = configuration.autocapitalizationType
        input.autocorrectionType = configuration.autocorrectionType
        input.spellCheckingType = configuration.spellCheckingType
        input.textContentType = configuration.textContentType
        input.dataDetectorTypes = configuration.dataDetectorTypes
        input.tintColor = configuration.caretColor
        input.textContainerInset = Self.insets(configuration.textContainerInset, in: direction)

        if isEnabled {
            input.accessibilityTraits.remove(.notEnabled)
        } else {
            input.accessibilityTraits.insert(.notEnabled)
        }
    }

    /// The string is the caller's content, so only a new `contentID` replaces it — which is what leaves
    /// whatever the user has typed where it is.
    private func seedText(node: FLTextEditor, environment: FLEnvironment) {
        let isSameContent = applied.map { $0.contentID == node.configuration.contentID }.orFalse
        guard !isSameContent else { return }
        input.attributedText = node.resolvedText(in: environment)
    }

    /// Rewrites the runs carrying the *previous* resolved value and leaves every other run alone, so a run
    /// the caller styled itself survives. Match on the value rather than on a range: ranges no longer line
    /// up with the node's string once the user has edited.
    private func restyle(to style: AppliedContent.Style) {
        guard let previousStyle = applied?.style, previousStyle != style else { return }

        let storage = input.textStorage
        let range = NSRange(location: 0, length: storage.length)

        guard range.length > 0 else { return }

        storage.beginEditing()
        Self.restyle(.font, in: storage, over: range, from: previousStyle.font, to: style.font)
        Self.restyle(.foregroundColor, in: storage, over: range, from: previousStyle.color, to: style.color)
        storage.endEditing()
    }

    private static func restyle<Value: Equatable>(
        _ key: NSAttributedString.Key,
        in storage: NSTextStorage,
        over range: NSRange,
        from previous: Value,
        to current: Value
    ) {
        var staleRanges: [NSRange] = []

        storage.enumerateAttribute(key, in: range, options: []) { value, subrange, _ in
            guard let value = value as? Value, value == previous else { return }
            staleRanges.append(subrange)
        }

        for subrange in staleRanges {
            storage.addAttribute(key, value: current, range: subrange)
        }
    }

    private static func insets(_ insets: FLEdgeInsets, in direction: FLLayoutDirection) -> UIEdgeInsets {
        let left = insets.left(in: direction)

        return UIEdgeInsets(
            top: insets.top,
            left: left,
            bottom: insets.bottom,
            right: insets.horizontal - left
        )
    }
}

// MARK: - AppliedContent

private extension FLTextEditorView {
    struct AppliedContent: Hashable {
        let contentID: FLContentIdentity?
        let style: Style

        struct Style: Hashable {
            let font: UIFont
            let color: UIColor
        }
    }
}
