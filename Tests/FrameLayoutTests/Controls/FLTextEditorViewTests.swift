import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Text editor rendering")
struct FLTextEditorRenderingTests {
    private typealias Tagged = FLTagged<FLTextEditor, String>

    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted(_ node: FLTextEditor) -> FLHostView<Tagged> {
        let host = FLHostView<Tagged>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(node, to: host)

        return host
    }

    private func apply(_ node: FLTextEditor, to host: FLHostView<Tagged>) {
        let tagged = node.tag("editor")
        let layout = tagged.layout(in: FLContext(width: 320))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: tagged, layout: layout)
        host.layoutIfNeeded()
    }

    private func input(in host: FLHostView<Tagged>) -> FLTextEditorInput? {
        host.registry.view(withTag: "editor", as: FLTextEditorInput.self)
    }


    @Test("the text view is TextKit 1 with no padding of its own, so it renders what was measured")
    func rendersThroughTheMeasuredStack() {
        let host = hosted(FLTextEditor("Hello there"))

        #expect(input(in: host)?.text == "Hello there")
        #expect(input(in: host)?.textContainer.lineFragmentPadding == 0)
        #expect(input(in: host)?.textContainerInset == .zero)
        #expect(input(in: host)?.isScrollEnabled == false)
        #expect(input(in: host)?.layoutManager != nil)
    }

    @Test("a consumer delegate is forwarded to, and cannot displace the editor's own")
    func delegateIsForwardedRatherThanReplaced() {
        let host = hosted(FLTextEditor("", placeholder: "Type here"))
        let spy = DelegateSpy()

        input(in: host)?.delegate = spy
        input(in: host)?.insertText("a")

        #expect(spy.changes == 1)
        #expect(input(in: host)?.delegate !== spy)
        #expect(input(in: host)?.isShowingPlaceholder == false)
    }

    @Test("a delegate method the editor does not implement still reaches the consumer")
    func unimplementedDelegateMethodsForward() {
        let host = hosted(FLTextEditor(""))
        let spy = DelegateSpy()

        input(in: host)?.delegate = spy
        input(in: host)?.becomeFirstResponder()

        #expect(spy.beganEditing == 1)
    }

    @Test("the placeholder shows only while the editor is empty")
    func placeholderVisibility() {
        let empty = hosted(FLTextEditor("", placeholder: "Type here"))
        let filled = hosted(FLTextEditor("Hi", placeholder: "Type here"))

        #expect(input(in: empty)?.isShowingPlaceholder == true)
        #expect(input(in: empty)?.attributedPlaceholder?.string == "Type here")
        #expect(input(in: filled)?.isShowingPlaceholder == false)
    }

    // The alignment guarantee: the prompt is drawn by a text view configured like the one beside it, so
    // the two share a first line instead of being lined up by arithmetic that has to stay correct.
    @Test("the placeholder is laid out by the same container geometry as the text")
    func placeholderSharesTheTextGeometry() {
        let host = hosted(FLTextEditor("", placeholder: "Type here").textContainerInset(.all(12)))
        let placeholder = input(in: host)?.subviews.compactMap { $0 as? UITextView }.first

        #expect(placeholder != nil)
        #expect(placeholder?.textContainerInset == input(in: host)?.textContainerInset)
        #expect(placeholder?.textContainer.lineFragmentPadding == 0)
        #expect(placeholder?.isScrollEnabled == false)
        #expect(placeholder?.frame.size == input(in: host)?.bounds.size)
    }

    // Measurement reads the resolved font, so a restyle that never reached the glyphs would leave the box
    // and the text disagreeing about how big the content is.
    @Test("a restyle reaches the rendered text without a new contentID")
    func restyleReachesTheText() {
        let host = hosted(FLTextEditor("Hello").font(.systemFont(ofSize: 12)))

        apply(FLTextEditor("Hello").font(.systemFont(ofSize: 40)), to: host)

        #expect(renderedFontSize(in: host) == 40)
    }

    @Test("a restyle leaves what the user typed in place")
    func restyleKeepsTypedText() {
        let host = hosted(FLTextEditor("").font(.systemFont(ofSize: 12)))

        input(in: host)?.insertText("a draft")
        apply(FLTextEditor("").font(.systemFont(ofSize: 40)), to: host)

        #expect(input(in: host)?.text == "a draft")
        #expect(renderedFontSize(in: host) == 40)
    }

    // Only styling from outside the string can go stale, so a restyle must reach the runs that took the
    // resolved value and no others — a run the caller styled itself is content, and content is seeded.
    @Test("a restyle leaves a run the caller styled itself alone")
    func restyleKeepsTheCallersOwnRun() {
        let styled = NSMutableAttributedString(string: "plain bold")
        styled.addAttribute(
            .font,
            value: UIFont.boldSystemFont(ofSize: 30),
            range: NSRange(location: 6, length: 4)
        )

        let host = hosted(FLTextEditor(FLAttributedString(styled)).font(.systemFont(ofSize: 12)))

        apply(FLTextEditor(FLAttributedString(styled)).font(.systemFont(ofSize: 40)), to: host)

        let text = input(in: host)?.attributedText
        let plain = text?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let bold = text?.attribute(.font, at: 6, effectiveRange: nil) as? UIFont

        #expect(plain?.pointSize == 40)
        #expect(bold?.pointSize == 30)
    }

    // Assigning `attributedText` replaces `typingAttributes`, so a seed whose string ends in the caller's
    // own run would otherwise hand that run's style to everything typed next — and a later restyle, which
    // looks for the resolved value, would skip it.
    @Test("text typed after a seed carries the resolved style, not the string's trailing run")
    func typedTextCarriesTheResolvedStyle() {
        let styled = NSMutableAttributedString(string: "plain ")
        styled.append(
            NSAttributedString(string: "bold", attributes: [.font: UIFont.boldSystemFont(ofSize: 30)])
        )

        let host = hosted(FLTextEditor(FLAttributedString(styled)).font(.systemFont(ofSize: 12)))

        input(in: host)?.insertText("!")

        let typed = input(in: host)?.attributedText
        let last = typed.map { $0.attribute(.font, at: $0.length - 1, effectiveRange: nil) as? UIFont }

        #expect(last??.pointSize == 12)
    }

    private func renderedFontSize(in host: FLHostView<Tagged>) -> CGFloat? {
        let text = input(in: host)?.attributedText

        guard let text, text.length > 0 else { return nil }

        return (text.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize
    }

    // The reason the text is seeded rather than driven: a re-render the caller did not ask for must not
    // reach in and replace what the user has typed.
    @Test("typing survives a re-render the caller did not drive")
    func typingSurvivesAReRender() {
        let node = FLTextEditor("")
        let host = hosted(node)

        input(in: host)?.insertText("a draft")
        apply(node, to: host)

        #expect(input(in: host)?.text == "a draft")
    }

    @Test("a new contentID re-seeds the editor, so a recycled view takes the new item's text")
    func newContentReseeds() {
        let host = hosted(FLTextEditor("one").contentID("first"))

        input(in: host)?.insertText("!")
        apply(FLTextEditor("two").contentID("second"), to: host)

        #expect(input(in: host)?.text == "two")
    }

    @Test("an unchanged contentID leaves the editor alone even when the node's text differs")
    func unchangedContentKeepsTheEditorsText() {
        let host = hosted(FLTextEditor("one").contentID("first"))

        apply(FLTextEditor("two").contentID("first"), to: host)

        #expect(input(in: host)?.text == "one")
    }
}

private final class DelegateSpy: NSObject, UITextViewDelegate {
    private(set) var changes = 0
    private(set) var beganEditing = 0

    func textViewDidChange(_ textView: UITextView) {
        changes += 1
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        beganEditing += 1
    }
}
