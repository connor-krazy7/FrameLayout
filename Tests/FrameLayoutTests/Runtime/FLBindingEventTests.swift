import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Binding events")
struct FLBindingEventTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<BindingRow> {
        let host = FLHost<BindingRow>()
        let node = BindingRow(showsOptional: false).node
        let layout = node.layout(in: FLContext(width: 300))

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        return host
    }

    @Test("one identifier cannot cover several events: the second add replaces the handler")
    func identifiersAreNotKeyedPerEvent() {
        let control = UIControl()
        let identifier = UIAction.Identifier("shared")
        var fired: [String] = []

        control.addAction(UIAction(identifier: identifier) { _ in fired.append("down") }, for: .touchDown)
        control.addAction(UIAction(identifier: identifier) { _ in fired.append("up") }, for: .touchUpInside)
        control.sendActions(for: .touchDown)
        control.sendActions(for: .touchUpInside)

        #expect(fired == ["up", "up"])
    }

    @Test("removing by identifier with allEvents clears every event it was on")
    func removalAcrossTheMask() {
        let control = UIControl()
        let identifier = UIAction.Identifier("shared")
        var fired = 0

        control.addAction(UIAction(identifier: identifier) { _ in fired += 1 }, for: .touchDown)
        control.addAction(UIAction(identifier: identifier) { _ in fired += 1 }, for: .touchUpInside)
        control.removeAction(identifiedBy: identifier, for: .allEvents)
        control.sendActions(for: .touchDown)
        control.sendActions(for: .touchUpInside)

        #expect(fired == 0)
    }

    @Test("a compound mask reports which event actually fired")
    func compoundMaskReportsTheEvent() {
        let host = hosted()
        var received: [UIControl.Event] = []

        host.registry.bindAction(withTag: BindingPart.always, for: [.touchDown, .touchUpInside]) { received.append($0) }

        let button = host.registry.button(withTag: BindingPart.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == [.touchDown, .touchUpInside])
    }

    @Test("allEvents resolves to the concrete events, not the raw mask")
    func allEventsResolves() {
        let host = hosted()
        var received: [UIControl.Event] = []

        host.registry.bindAction(withTag: BindingPart.always, for: .allEvents) { received.append($0) }
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchDragExit)

        #expect(received == [.touchDragExit])
    }

    @Test("rebinding with a narrower mask detaches the events it dropped")
    func rebindingNarrowsTheMask() {
        let host = hosted()
        var received: [UIControl.Event] = []

        host.registry.bindAction(withTag: BindingPart.always, for: [.touchDown, .touchUpInside]) { received.append($0) }
        host.registry.bindAction(withTag: BindingPart.always, for: .touchUpInside) { received.append($0) }

        let button = host.registry.button(withTag: BindingPart.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == [.touchUpInside])
    }

    @Test("unbinding detaches every event the binding covered")
    func unbindingACompoundMask() {
        let host = hosted()
        var received = 0

        host.registry.bindAction(withTag: BindingPart.always, for: [.touchDown, .touchUpInside]) { _ in received += 1 }
        host.registry.unbindAction(withTag: BindingPart.always)

        let button = host.registry.button(withTag: BindingPart.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == 0)
    }
}
