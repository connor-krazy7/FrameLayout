import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Button")
struct FLButtonTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted(isSendEnabled: Bool = true) -> FLHost<ButtonToolbar> {
        let host = FLHost<ButtonToolbar>()
        let node = ButtonToolbar(isSendEnabled: isSendEnabled).node
        let layout = node.layout(in: FLContext(width: 320))

        host.frame = CGRect(origin: .zero, size: layout.size)
        window.addSubview(host)
        window.makeKeyAndVisible()
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    private func control(_ part: ButtonRowPart, in host: FLHost<ButtonToolbar>) -> UIControl? {
        host.registry.button(withTag: part)
    }

    @Test("wrapping content in a button does not change layout")
    func layoutIsUnaffected() {
        let content = FLText("Send").padding(10)
        let wrapped = FLButton(tag: ButtonRowPart.send) { FLText("Send").padding(10) }
        let context = FLContext(width: 300)

        #expect(wrapped.layout(in: context).size == content.layout(in: context).size)
    }

    @Test("a tagged button is reachable as a UIControl, so a cell can attach an action")
    func reachableAsAControl() {
        let host = hosted()
        var sent = 0

        #expect(control(.send, in: host) != nil)

        control(.send, in: host)?.addAction(UIAction { _ in sent += 1 }, for: .touchUpInside)
        control(.send, in: host)?.sendActions(for: .touchUpInside)

        #expect(sent == 1)
    }

    @Test("the button claims the touch and its content does not")
    func buttonClaimsTheTouch() {
        let host = hosted()
        let send = control(.send, in: host)
        let hit = host.hitTest(CGPoint(x: 10, y: 10), with: nil)

        #expect(hit === send)
        #expect(send?.subviews.first?.isUserInteractionEnabled == false)
    }

    @Test("pressing dims and scales the content, releasing restores it")
    func pressedStateAppliesToContent() {
        let host = hosted()
        let send = control(.send, in: host)
        let content = send?.subviews.first

        #expect(content?.alpha == 1)
        #expect(content?.transform == .identity)

        send?.isHighlighted = true

        #expect(content?.alpha == 1)
        #expect(content?.transform.a == 0.94)

        send?.isHighlighted = false

        #expect(content?.alpha == 1)
        #expect(content?.transform == .identity)
    }

    @Test("the default style dims without scaling")
    func defaultStyleDims() {
        let host = hosted()
        let cancel = control(.cancel, in: host)
        let content = cancel?.subviews.first

        cancel?.isHighlighted = true

        #expect(abs((content?.alpha ?? 0) - 0.6) < 0.001)
        #expect(content?.transform == .identity)
    }

    @Test("a disabled button reports disabled and is out of the hit path")
    func disabledButton() {
        let host = hosted(isSendEnabled: false)
        let send = control(.send, in: host)

        #expect(send?.isEnabled == false)
        #expect(host.hitTest(CGPoint(x: 10, y: 10), with: nil) !== send)
    }

    @Test("a button carries the accessibility traits UIButton would")
    func accessibility() {
        let host = hosted()
        let send = control(.send, in: host)
        let disabled = control(.send, in: hosted(isSendEnabled: false))

        #expect(send?.isAccessibilityElement == true)
        #expect(send?.accessibilityTraits.contains(.button) == true)
        #expect(send?.accessibilityLabel == "Send")
        #expect(disabled?.accessibilityTraits.contains(.notEnabled) == true)
    }

    @Test("the tag and style take part in node equality")
    func stateAffectsIdentity() {
        func button(tag: ButtonRowPart, style: FLButtonStyle) -> FLButton<FLPadded<FLText>, ButtonRowPart> {
            FLButton(tag: tag, style: style) { FLText("Send").padding(10) }
        }

        #expect(button(tag: .send, style: .opacity()) == button(tag: .send, style: .opacity()))
        #expect(button(tag: .send, style: .opacity()) != button(tag: .cancel, style: .opacity()))
        #expect(button(tag: .send, style: .opacity()) != button(tag: .send, style: .scaling()))
    }

    @Test("disabling a subtree reaches every button inside it")
    func disablingPropagates() {
        let host = hosted(isSendEnabled: true)
        let disabled = hosted(isSendEnabled: false)

        #expect(control(.send, in: host)?.isEnabled == true)
        #expect(control(.cancel, in: host)?.isEnabled == true)
        #expect(control(.send, in: disabled)?.isEnabled == false)
        #expect(control(.cancel, in: disabled)?.isEnabled == true)
    }

    @Test("sendActions ignores isEnabled, so a disabled button must be blocked by touch, not by dispatch")
    func sendActionsBypassesEnabled() {
        let host = hosted(isSendEnabled: false)
        let send = control(.send, in: host)
        var fired = 0

        send?.addAction(UIAction { _ in fired += 1 }, for: .touchUpInside)
        send?.sendActions(for: .touchUpInside)

        #expect(send?.isEnabled == false)
        #expect(fired == 1)
    }
}
