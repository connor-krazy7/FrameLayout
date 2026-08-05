import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Unbinding")
struct FLUnbindingTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func host() -> FLHost<BindingRow> {
        let host = FLHost<BindingRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()

        return host
    }

    private func apply(_ showsOptional: Bool, to host: FLHost<BindingRow>) {
        let node = BindingRow(showsOptional: showsOptional).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
    }

    @Test("unbinding stops a later view from being configured")
    func unbindingStopsFutureViews() {
        let host = host()
        var configured = 0

        host.registry.bindView(withTag: BindingPart.sometimes) { _ in configured += 1 }
        host.registry.unbindView(withTag: BindingPart.sometimes)
        apply(true, to: host)

        #expect(configured == 0)
    }

    @Test("a view binding and an action binding are unbound independently")
    func viewAndActionUnbindIndependently() {
        let host = host()
        var configured = 0
        var taps = 0

        host.registry.bindView(withTag: BindingPart.sometimes) { _ in configured += 1 }
        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in taps += 1 }
        host.registry.unbindView(withTag: BindingPart.sometimes)
        apply(true, to: host)
        host.registry.button(withTag: BindingPart.sometimes)?.sendActions(for: .touchUpInside)

        #expect(configured == 0)
        #expect(taps == 1)
    }

    @Test("unbinding one key leaves the others in place")
    func unbindingIsPerKey() {
        let host = host()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.unbindView(withTag: BindingPart.always, bindingKey: "analytics")
        apply(false, to: host)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 0)
        #expect(navigation == 1)
    }

    @Test("unbindAll(withTag:) clears one tag and leaves another alone")
    func unbindingATag() {
        let host = host()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in always += 1 }
        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll(withTag: BindingPart.always)
        apply(true, to: host)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: BindingPart.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 1)
    }

    @Test("unbindAction also detaches the action already on the control")
    func unbindActionDetachesTheLiveAction() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        apply(false, to: host)
        host.registry.unbindAction(withTag: BindingPart.always)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 0)
    }

    @Test("unbindButton is the view-level counterpart, leaving attached actions alone")
    func unbindButtonOnlyStopsFutureConfiguration() {
        let host = host()
        var configured = 0
        var taps = 0

        host.registry.bindButton(withTag: BindingPart.sometimes) { _ in configured += 1 }
        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in taps += 1 }
        host.registry.unbindButton(withTag: BindingPart.sometimes)
        apply(true, to: host)
        host.registry.button(withTag: BindingPart.sometimes)?.sendActions(for: .touchUpInside)

        #expect(configured == 0)
        #expect(taps == 1)
    }

    @Test("unbindView leaves an already attached action alone, so a live button keeps working")
    func unbindViewDoesNotUndo() {
        let host = host()
        var taps = 0
        let bindingKey = "live"

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: bindingKey) { _ in taps += 1 }
        apply(false, to: host)
        host.registry.unbindView(withTag: BindingPart.always, bindingKey: bindingKey)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 1)
    }
}
