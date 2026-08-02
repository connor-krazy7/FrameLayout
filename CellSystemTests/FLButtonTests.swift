import Testing
import UIKit

@testable import CellSystem

private enum RowPart: Hashable, Sendable {
    case send
    case cancel
}

private struct Toolbar: FLView {
    let isSendEnabled: Bool

    var body: some FLNode {
        FLHStack(spacing: 8) {
            FLButton(tag: RowPart.send, style: .scaling(0.94)) {
                FLText("Send")
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.systemBlue, in: .capsule)
            }
            .accessibilityLabel("Send")
            .disabled(!isSendEnabled)

            FLButton(tag: RowPart.cancel) {
                FLText("Cancel")
                    .foregroundColor(.systemBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
    }
}

@MainActor
@Suite("Button")
struct FLButtonTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted(isSendEnabled: Bool = true) -> FLHost<Toolbar> {
        let host = FLHost<Toolbar>()
        let node = Toolbar(isSendEnabled: isSendEnabled).node
        let layout = node.layout(in: FLContext(width: 320))

        host.frame = CGRect(origin: .zero, size: layout.size)
        window.addSubview(host)
        window.makeKeyAndVisible()
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    private func control(_ part: RowPart, in host: FLHost<Toolbar>) -> UIControl? {
        host.registry.button(withTag: part)
    }

    @Test("wrapping content in a button does not change layout")
    func layoutIsUnaffected() {
        let content = FLText("Send").padding(10)
        let wrapped = FLButton(tag: RowPart.send) { FLText("Send").padding(10) }
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
        func button(tag: RowPart, style: FLButtonStyle) -> FLButton<FLPadded<FLText>, RowPart> {
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

@MainActor
@Suite("Button playground")
struct FLButtonPlaygroundTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))

    private func hosted(isDisabled: Bool) -> FLHost<ButtonDemoToolbar> {
        let host = FLHost<ButtonDemoToolbar>()
        let node = ButtonDemoToolbar(isDisabled: isDisabled).node
        let layout = node.layout(in: FLContext(width: 320))

        host.frame = CGRect(origin: .zero, size: layout.size)
        window.addSubview(host)
        window.makeKeyAndVisible()
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("every button in the toolbar is reachable by its tag")
    func allButtonsAreReachable() {
        let host = hosted(isDisabled: false)

        for part in [ButtonDemoPart.send, .cancel, .more, .card] {
            #expect(host.registry.button(withTag: part) != nil)
        }
    }

    @Test("one disabled modifier turns the whole toolbar off")
    func disablingTheToolbar() {
        let enabled = hosted(isDisabled: false)
        let disabled = hosted(isDisabled: true)

        for part in [ButtonDemoPart.send, .cancel, .more, .card] {
            #expect(enabled.registry.button(withTag: part)?.isEnabled == true)
            #expect(disabled.registry.button(withTag: part)?.isEnabled == false)
        }
    }

    @Test("each button carries its own accessibility label")
    func labelsSurviveTheChain() {
        let host = hosted(isDisabled: false)

        #expect(host.registry.button(withTag: ButtonDemoPart.send)?.accessibilityLabel == "Send message")
        #expect(host.registry.button(withTag: ButtonDemoPart.more)?.accessibilityLabel == "More actions")
        #expect(host.registry.button(withTag: ButtonDemoPart.card)?.accessibilityLabel == "Open profile")
    }

    @Test("disabling does not change layout")
    func disablingIsLayoutNeutral() {
        let context = FLContext(width: 320)

        #expect(
            ButtonDemoToolbar(isDisabled: true).node.layout(in: context).size
                == ButtonDemoToolbar(isDisabled: false).node.layout(in: context).size
        )
    }
}
