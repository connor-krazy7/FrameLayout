import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Bindings")
struct FLBindingTests {
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
        host.layoutIfNeeded()
    }

    private func tap(_ part: BindingPart, in host: FLHost<BindingRow>) {
        host.registry.button(withTag: part)?.sendActions(for: .touchUpInside)
    }

    @Test("a binding declared before the first apply reaches the view when it arrives")
    func bindingPrecedesApply() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        apply(false, to: host)
        tap(.always, in: host)

        #expect(taps == 1)
    }

    @Test("a binding declared after an apply reaches the view already there")
    func bindingFollowsApply() {
        let host = host()
        var taps = 0

        apply(false, to: host)
        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        tap(.always, in: host)

        #expect(taps == 1)
    }

    @Test("reapplying does not stack a second handler on the same view")
    func reapplyingDoesNotDuplicate() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        apply(false, to: host)
        apply(true, to: host)
        apply(false, to: host)
        tap(.always, in: host)

        #expect(taps == 1)
    }

    @Test("a part that only appears later is bound when it appears")
    func laterPartIsBoundOnArrival() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in taps += 1 }
        apply(false, to: host)

        #expect(host.registry.button(withTag: BindingPart.sometimes) == nil)

        apply(true, to: host)
        tap(.sometimes, in: host)

        #expect(taps == 1)
    }

    @Test("a part that leaves and returns is still bound, exactly once")
    func returningPartStaysBound() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in taps += 1 }
        apply(true, to: host)
        apply(false, to: host)
        apply(true, to: host)
        tap(.sometimes, in: host)

        #expect(taps == 1)
    }

    @Test("rebinding replaces the previous handler rather than adding to it")
    func rebindingReplaces() {
        let host = host()
        var first = 0
        var second = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in first += 1 }
        apply(false, to: host)
        host.registry.bindAction(withTag: BindingPart.always) { _ in second += 1 }
        tap(.always, in: host)

        #expect(first == 0)
        #expect(second == 1)
    }

    @Test("unbindAll stops future views from being configured")
    func unbinding() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in taps += 1 }
        host.registry.unbindAll()
        apply(true, to: host)
        tap(.sometimes, in: host)

        #expect(taps == 0)
    }

    @Test("a general binding can configure any view, not only a control")
    func generalBinding() {
        let host = host()
        var configured = 0

        host.registry.bindView(withTag: BindingPart.always) { view in
            view.accessibilityIdentifier = "bound"
            configured += 1
        }
        apply(false, to: host)
        apply(true, to: host)

        #expect(configured == 1)
        #expect(host.registry.view(withTag: BindingPart.always)?.accessibilityIdentifier == "bound")
    }
}
