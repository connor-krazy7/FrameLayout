import UIKit

public struct FLTextEditorConfiguration: Sendable, FLLayoutEquatable, WithCustomisable {
    public var contentID: FLContentIdentity?
    /// The text is measured inside it, so it grows the box wherever the editor hugs and eats into the
    /// text area wherever the editor fills.
    public var textContainerInset: FLEdgeInsets = .zero
    /// Whether the text scrolls inside the frame the layout gave it. Sizing does not read this: an
    /// editable editor already takes the box it is offered.
    public var isScrollEnabled = false
    /// An editable editor takes the box it was offered on both axes, falling back to its content when
    /// nothing was offered — which is what lets a frame size it, what self-sizes a cell, and what makes
    /// it answer zero to a `.minimum` proposal, so a squeezed stack can collapse it. A display-only one
    /// hugs its text instead, measuring exactly as the `FLText` beside it would.
    public var isEditable = true
    public var isSelectable = true
    public var clearsOnInsertion = false
    public var showsIndicators = true
    public var keyboardType: UIKeyboardType = .default
    public var returnKeyType: UIReturnKeyType = .default
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    public var autocorrectionType: UITextAutocorrectionType = .default
    public var spellCheckingType: UITextSpellCheckingType = .default
    public var textContentType: UITextContentType?
    public var caretColor: UIColor?
    /// `UIDataDetectorTypes` is an `OptionSet` with no `Hashable` conformance, which would block
    /// synthesis here. See `node-equality.md`.
    private var detectorTypes: UInt = 0

    public var dataDetectorTypes: UIDataDetectorTypes {
        get { UIDataDetectorTypes(rawValue: detectorTypes) }
        set { detectorTypes = newValue.rawValue }
    }

    public init() {}
}

// MARK: - FLLayoutEquatable

public extension FLTextEditorConfiguration {
    /// The two fields `FLTextEditor.layout(in:)` reads. Everything else reaches the text view at update.
    func isLayoutEquivalent(to other: FLTextEditorConfiguration) -> Bool {
        textContainerInset == other.textContainerInset && isEditable == other.isEditable
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(textContainerInset)
        hasher.combine(isEditable)
    }
}
