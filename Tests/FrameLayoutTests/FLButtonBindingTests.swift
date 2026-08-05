import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Button bindings")
struct FLButtonBindingTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<BindingRow> {
        let host = FLHost<BindingRow>()
        let node = BindingRow(showsOptional: true).node
        let layout = node.layout(in: FLContext(width: 300))

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        return host
    }

    @Test("the control-typed binding hands over the UIControl itself")
    func controlTypedBinding() {
        let host = hosted()
        var configured = 0

        host.registry.bindButton(withTag: BindingPart.always) { control in
            control.isEnabled = false
            configured += 1
        }

        #expect(configured == 1)
        #expect(host.registry.button(withTag: BindingPart.always)?.isEnabled == false)
    }

    @Test("two bindings with different identifiers both fire")
    func distinctIdentifiersCoexist() {
        let host = hosted()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 1)
        #expect(navigation == 1)
    }

    @Test("both survive when they are declared before the view exists")
    func distinctIdentifiersSurviveALateView() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let host = FLHost<BindingRow>()
        var analytics = 0
        var navigation = 0

        window.addSubview(host)
        window.makeKeyAndVisible()

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "navigation") { _ in navigation += 1 }

        let node = BindingRow(showsOptional: false).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 1)
        #expect(navigation == 1)
    }

    @Test("a view binding and a button binding coexist on one tag")
    func viewAndButtonBindingsCoexist() {
        let host = hosted()
        var taps = 0
        var configured = 0

        host.registry.bindView(withTag: BindingPart.always) { view in
            view.accessibilityIdentifier = "bound"
            configured += 1
        }
        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(configured == 1)
        #expect(taps == 1)
        #expect(host.registry.view(withTag: BindingPart.always)?.accessibilityIdentifier == "bound")
    }

    @Test("the same identifier replaces, so a rebind does not double up")
    func sameIdentifierReplaces() {
        let host = hosted()
        var first = 0
        var second = 0
        let bindingKey = "shared"

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: bindingKey) { _ in first += 1 }
        host.registry.bindAction(withTag: BindingPart.always, bindingKey: bindingKey) { _ in second += 1 }
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(first == 0)
        #expect(second == 1)
    }

    @Test("different events on one button are independent")
    func eventsAreIndependent() {
        let host = hosted()
        var taps = 0
        var downs = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        host.registry.bindAction(withTag: BindingPart.always, for: .touchDown) { _ in downs += 1 }

        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchDown)

        #expect(taps == 0)
        #expect(downs == 1)
    }
}
