import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

@MainActor
@Suite("Button playground")
struct FLButtonPlaygroundTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))

    private func hosted(isDisabled: Bool) -> FLHost<ButtonDemoToolbar> {
        let host = FLHost<ButtonDemoToolbar>()
        let node = ButtonDemoToolbar(isDisabled: isDisabled, showsRetry: false).node
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

    @Test("a binding declared once reaches the conditional button when it appears")
    func conditionalButtonIsBoundOnArrival() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let host = FLHost<ButtonDemoToolbar>()
        var retries = 0

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindAction(withTag: ButtonDemoPart.retry) { _ in retries += 1 }

        func apply(showsRetry: Bool) {
            let node = ButtonDemoToolbar(isDisabled: false, showsRetry: showsRetry).node
            let layout = node.layout(in: FLContext(width: 320))

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(showsRetry: false)

        #expect(host.registry.button(withTag: ButtonDemoPart.retry) == nil)

        apply(showsRetry: true)
        host.registry.button(withTag: ButtonDemoPart.retry)?.sendActions(for: .touchUpInside)

        #expect(retries == 1)

        apply(showsRetry: false)
        apply(showsRetry: true)
        host.registry.button(withTag: ButtonDemoPart.retry)?.sendActions(for: .touchUpInside)

        #expect(retries == 2)
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
            ButtonDemoToolbar(isDisabled: true, showsRetry: false).node.layout(in: context).size
                == ButtonDemoToolbar(isDisabled: false, showsRetry: false).node.layout(in: context).size
        )
    }
}
