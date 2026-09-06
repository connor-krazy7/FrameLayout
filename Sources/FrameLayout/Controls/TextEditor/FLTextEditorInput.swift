import UIKit

// MARK: - Input

/// The `UITextView` inside an `FLTextEditor`. Assigning `delegate` sets a forwarding target rather than
/// replacing the editor's own, so the editor keeps the callbacks it needs; reading it gives the
/// forwarder, which is what UIKit must find there.
public final class FLTextEditorInput: UITextView {
    /// Drawn by a second text view configured exactly like this one, so the prompt lands on the same
    /// first line the typed text will. A `UILabel` centres its text in its frame where a text view starts
    /// at the top, which puts the two out of line the moment the editor is taller than one line.
    public var attributedPlaceholder: NSAttributedString? {
        get { placeholder.attributedText }
        set {
            placeholder.attributedText = newValue
            updatePlaceholderVisibility()
        }
    }

    public override var textContainerInset: UIEdgeInsets {
        didSet { placeholder.textContainerInset = textContainerInset }
    }

    /// Assigning text does not call the delegate, so the two setters a caller can reach are where the
    /// prompt is hidden and shown. Typing arrives at `textViewDidChange` instead.
    public override var attributedText: NSAttributedString! {
        didSet { updatePlaceholderVisibility() }
    }

    public override var text: String! {
        didSet { updatePlaceholderVisibility() }
    }

    private let placeholder = UITextView().then {
        $0.backgroundColor = .clear
        $0.textAlignment = .natural
        $0.isEditable = false
        $0.isSelectable = false
        $0.isUserInteractionEnabled = false
        $0.isScrollEnabled = false
        $0.textContainerInset = .zero
        $0.textContainer.lineFragmentPadding = 0
    }

    private let forwarder = FLTextEditorDelegateForwarder()

    public override var delegate: UITextViewDelegate? {
        get { super.delegate }
        set {
            forwarder.target = newValue
            // UIKit caches which selectors a delegate answers, so a newly assigned target is not
            // dispatched to until the forwarder is re-seated.
            super.delegate = nil
            super.delegate = forwarder
        }
    }

    /// Builds the TextKit 1 stack `FLTextMeasurement` measures with. A `UITextView` left to itself is
    /// TextKit 2, which is not that engine.
    public init() {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer()

        storage.addLayoutManager(manager)
        manager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)

        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        forwarder.owner = self
        super.delegate = forwarder
        addSubview(placeholder)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        placeholder.frame = CGRect(origin: contentOffset, size: bounds.size)
    }

    var isShowingPlaceholder: Bool { !placeholder.isHidden }

    fileprivate func updatePlaceholderVisibility() {
        placeholder.isHidden = !text.isEmpty
    }
}

// MARK: - Forwarder

private final class FLTextEditorDelegateForwarder: NSObject, UITextViewDelegate {
    weak var target: UITextViewDelegate?
    weak var owner: FLTextEditorInput?

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || target?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        target?.responds(to: selector) == true ? target : nil
    }

    func textViewDidChange(_ textView: UITextView) {
        owner?.updatePlaceholderVisibility()
        target?.textViewDidChange?(textView)
    }
}
