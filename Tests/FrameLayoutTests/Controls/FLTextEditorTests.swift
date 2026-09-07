import Testing
import UIKit

@testable import FrameLayout

@Suite("Text editor")
struct FLTextEditorTests {
    private static let sample = """
        Every node here is a single-child generic wrapper, so the content tree and the view tree \
        are the same type by construction.
        """

    private static var font: UIFont { .systemFont(ofSize: 16) }
    private static var environment: FLEnvironment { FLEnvironment(font: Self.font) }

    private func context(width: CGFloat) -> FLContext {
        FLContext(width: width, environment: Self.environment)
    }

    private func identity(of node: FLTextEditor) -> Int {
        var hasher = Hasher()
        node.hashLayoutIdentity(into: &hasher)

        return hasher.finalize()
    }

    // The contract `FLTextMeasurement` exists for: both text nodes answer through it, so they cannot
    // drift. A display-only editor with no inset is an `FLText` with no line limit.
    @Test("a display-only editor measures the same box as an FLText of the same string")
    func matchesText() {
        let editor = FLTextEditor(Self.sample).editable(false).layout(in: context(width: 220)).size
        let text = FLText(Self.sample).layout(in: context(width: 220)).size

        #expect(editor == text)
    }

    @Test("an editable editor takes the width it was offered, so it is a target to tap")
    func editableFillsTheOfferedWidth() {
        let editable = FLTextEditor("hi").layout(in: context(width: 220)).size
        let display = FLTextEditor("hi").editable(false).layout(in: context(width: 220)).size

        #expect(editable.width == 220)
        #expect(display.width < 220)
        #expect(editable.height == display.height)
    }

    @Test("an empty editor reserves a line where an empty text reserves nothing")
    func emptyReservesALine() {
        let editor = FLTextEditor("").layout(in: context(width: 220)).size
        let text = FLText("").layout(in: context(width: 220)).size

        #expect(editor.height >= ceil(Self.font.lineHeight))
        #expect(text.height == 0)
    }

    @Test("the container inset grows the reserved box on both axes")
    func insetGrowsTheBox() {
        let unbounded = FLContext(environment: Self.environment)
        let plain = FLTextEditor("Hi").layout(in: unbounded).size
        let inset = FLTextEditor("Hi").textContainerInset(.all(8)).layout(in: unbounded).size

        #expect(inset.width == plain.width + 16)
        #expect(inset.height == plain.height + 16)
    }

    @Test("a placeholder changes nothing about the size, however long it is")
    func placeholderIsNotMeasured() {
        let bare = FLTextEditor("").layout(in: context(width: 220)).size
        let prompted = FLTextEditor("", placeholder: Self.sample).layout(in: context(width: 220)).size

        #expect(bare == prompted)
    }

    @Test("an editable editor takes the height it was offered, a display-only one its content")
    func editableTakesTheOfferedHeight() {
        let proposed = FLContext(width: .exact(220), height: .exact(500), environment: Self.environment)
        let editable = FLTextEditor(Self.sample).layout(in: proposed).size.height
        let display = FLTextEditor(Self.sample).editable(false).layout(in: proposed).size.height

        #expect(editable == 500)
        #expect(display < 500)
    }

    @Test("offered no height, an editable editor is its content, which is what self-sizes a cell")
    func editableHugsWhenNothingIsOffered() {
        let editor = FLTextEditor(Self.sample).layout(in: context(width: 220)).size.height
        let display = FLTextEditor(Self.sample).editable(false).layout(in: context(width: 220)).size.height

        #expect(editor == display)
    }

    // A decision rather than an oversight: an editable editor fills the box it is given, so the smallest
    // it can be is nothing — the answer every flexible leaf gives. A floor taken from the node's text
    // would also be stale, since after any typing the node's string is not what the view holds.
    @Test("asked for its minimum, an editable editor collapses where a display-only one hugs")
    func minimumCollapsesOnlyWhenEditable() {
        let squeezed = FLContext(width: .minimum, environment: Self.environment)
        let editable = FLTextEditor(Self.sample).layout(in: squeezed).size.width
        let display = FLTextEditor(Self.sample).editable(false).layout(in: squeezed).size.width
        let text = FLText(Self.sample).layout(in: squeezed).size.width

        #expect(editable == 0)
        #expect(display > 0)
        #expect(display == text)
    }

    @Test("behaviour that never reaches layout is layout-equivalent, so a cache still hits")
    func behaviourIsLayoutNeutral() {
        let plain = FLTextEditor(Self.sample)
        let configured = plain
            .keyboardType(.emailAddress)
            .returnKeyType(.send)
            .autocorrection(.no)
            .dataDetectorTypes(.link)
            .scrollEnabled()
            .caretColor(.systemPink)
            .placeholder("Type here")

        #expect(plain != configured)
        #expect(plain.isLayoutEquivalent(to: configured))
        #expect(identity(of: plain) == identity(of: configured))
    }

    @Test("the inset, editability and the font are not layout-neutral")
    func geometryIsNotNeutral() {
        let plain = FLTextEditor(Self.sample)

        #expect(plain.isLayoutEquivalent(to: plain.textContainerInset(.all(4))) == false)
        #expect(plain.isLayoutEquivalent(to: plain.editable(false)) == false)
        #expect(plain.isLayoutEquivalent(to: plain.font(.systemFont(ofSize: 30))) == false)
    }
}
