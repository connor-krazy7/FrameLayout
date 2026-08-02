import Testing
import UIKit

@testable import CellSystem

private enum Part: Hashable, Sendable {
    case always
    case sometimes
}

private struct Row: FLView {
    let showsOptional: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLButton(tag: Part.always) {
                FLColor(.systemBlue).frame(width: 80, height: 30)
            }

            if showsOptional {
                FLButton(tag: Part.sometimes) {
                    FLColor(.systemGreen).frame(width: 80, height: 30)
                }
            }
        }
    }
}

@MainActor
@Suite("Bindings")
struct FLBindingTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func host() -> FLHost<Row> {
        let host = FLHost<Row>()

        window.addSubview(host)
        window.makeKeyAndVisible()

        return host
    }

    private func apply(_ showsOptional: Bool, to host: FLHost<Row>) {
        let node = Row(showsOptional: showsOptional).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
    }

    private func tap(_ part: Part, in host: FLHost<Row>) {
        host.registry.button(withTag: part)?.sendActions(for: .touchUpInside)
    }

    @Test("a binding declared before the first apply reaches the view when it arrives")
    func bindingPrecedesApply() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        apply(false, to: host)
        tap(.always, in: host)

        #expect(taps == 1)
    }

    @Test("a binding declared after an apply reaches the view already there")
    func bindingFollowsApply() {
        let host = host()
        var taps = 0

        apply(false, to: host)
        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        tap(.always, in: host)

        #expect(taps == 1)
    }

    @Test("reapplying does not stack a second handler on the same view")
    func reapplyingDoesNotDuplicate() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
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

        host.registry.bindAction(withTag: Part.sometimes) { _ in taps += 1 }
        apply(false, to: host)

        #expect(host.registry.button(withTag: Part.sometimes) == nil)

        apply(true, to: host)
        tap(.sometimes, in: host)

        #expect(taps == 1)
    }

    @Test("a part that leaves and returns is still bound, exactly once")
    func returningPartStaysBound() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: Part.sometimes) { _ in taps += 1 }
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

        host.registry.bindAction(withTag: Part.always) { _ in first += 1 }
        apply(false, to: host)
        host.registry.bindAction(withTag: Part.always) { _ in second += 1 }
        tap(.always, in: host)

        #expect(first == 0)
        #expect(second == 1)
    }

    @Test("unbindAll stops future views from being configured")
    func unbinding() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: Part.sometimes) { _ in taps += 1 }
        host.registry.unbindAll()
        apply(true, to: host)
        tap(.sometimes, in: host)

        #expect(taps == 0)
    }

    @Test("a general binding can configure any view, not only a control")
    func generalBinding() {
        let host = host()
        var configured = 0

        host.registry.bindView(withTag: Part.always) { view in
            view.accessibilityIdentifier = "bound"
            configured += 1
        }
        apply(false, to: host)
        apply(true, to: host)

        #expect(configured == 1)
        #expect(host.registry.view(withTag: Part.always)?.accessibilityIdentifier == "bound")
    }
}

@MainActor
@Suite("Button bindings")
struct FLButtonBindingTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = Row(showsOptional: true).node
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

        host.registry.bindButton(withTag: Part.always) { control in
            control.isEnabled = false
            configured += 1
        }

        #expect(configured == 1)
        #expect(host.registry.button(withTag: Part.always)?.isEnabled == false)
    }

    @Test("two bindings with different identifiers both fire")
    func distinctIdentifiersCoexist() {
        let host = hosted()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: Part.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: Part.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 1)
        #expect(navigation == 1)
    }

    @Test("both survive when they are declared before the view exists")
    func distinctIdentifiersSurviveALateView() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let host = FLHost<Row>()
        var analytics = 0
        var navigation = 0

        window.addSubview(host)
        window.makeKeyAndVisible()

        host.registry.bindAction(withTag: Part.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: Part.always, bindingKey: "navigation") { _ in navigation += 1 }

        let node = Row(showsOptional: false).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 1)
        #expect(navigation == 1)
    }

    @Test("a view binding and a button binding coexist on one tag")
    func viewAndButtonBindingsCoexist() {
        let host = hosted()
        var taps = 0
        var configured = 0

        host.registry.bindView(withTag: Part.always) { view in
            view.accessibilityIdentifier = "bound"
            configured += 1
        }
        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(configured == 1)
        #expect(taps == 1)
        #expect(host.registry.view(withTag: Part.always)?.accessibilityIdentifier == "bound")
    }

    @Test("the same identifier replaces, so a rebind does not double up")
    func sameIdentifierReplaces() {
        let host = hosted()
        var first = 0
        var second = 0
        let bindingKey = "shared"

        host.registry.bindAction(withTag: Part.always, bindingKey: bindingKey) { _ in first += 1 }
        host.registry.bindAction(withTag: Part.always, bindingKey: bindingKey) { _ in second += 1 }
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(first == 0)
        #expect(second == 1)
    }

    @Test("different events on one button are independent")
    func eventsAreIndependent() {
        let host = hosted()
        var taps = 0
        var downs = 0

        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        host.registry.bindAction(withTag: Part.always, for: .touchDown) { _ in downs += 1 }

        host.registry.button(withTag: Part.always)?.sendActions(for: .touchDown)

        #expect(taps == 0)
        #expect(downs == 1)
    }
}

@MainActor
@Suite("Unbinding")
struct FLUnbindingTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func host() -> FLHost<Row> {
        let host = FLHost<Row>()

        window.addSubview(host)
        window.makeKeyAndVisible()

        return host
    }

    private func apply(_ showsOptional: Bool, to host: FLHost<Row>) {
        let node = Row(showsOptional: showsOptional).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
    }

    @Test("unbinding stops a later view from being configured")
    func unbindingStopsFutureViews() {
        let host = host()
        var configured = 0

        host.registry.bindView(withTag: Part.sometimes) { _ in configured += 1 }
        host.registry.unbindView(withTag: Part.sometimes)
        apply(true, to: host)

        #expect(configured == 0)
    }

    @Test("a view binding and an action binding are unbound independently")
    func viewAndActionUnbindIndependently() {
        let host = host()
        var configured = 0
        var taps = 0

        host.registry.bindView(withTag: Part.sometimes) { _ in configured += 1 }
        host.registry.bindAction(withTag: Part.sometimes) { _ in taps += 1 }
        host.registry.unbindView(withTag: Part.sometimes)
        apply(true, to: host)
        host.registry.button(withTag: Part.sometimes)?.sendActions(for: .touchUpInside)

        #expect(configured == 0)
        #expect(taps == 1)
    }

    @Test("unbinding one key leaves the others in place")
    func unbindingIsPerKey() {
        let host = host()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: Part.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: Part.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.unbindView(withTag: Part.always, bindingKey: "analytics")
        apply(false, to: host)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 0)
        #expect(navigation == 1)
    }

    @Test("unbindAll(withTag:) clears one tag and leaves another alone")
    func unbindingATag() {
        let host = host()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: Part.always) { _ in always += 1 }
        host.registry.bindAction(withTag: Part.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll(withTag: Part.always)
        apply(true, to: host)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: Part.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 1)
    }

    @Test("unbindAction also detaches the action already on the control")
    func unbindActionDetachesTheLiveAction() {
        let host = host()
        var taps = 0

        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        apply(false, to: host)
        host.registry.unbindAction(withTag: Part.always)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 0)
    }

    @Test("unbindButton is the view-level counterpart, leaving attached actions alone")
    func unbindButtonOnlyStopsFutureConfiguration() {
        let host = host()
        var configured = 0
        var taps = 0

        host.registry.bindButton(withTag: Part.sometimes) { _ in configured += 1 }
        host.registry.bindAction(withTag: Part.sometimes) { _ in taps += 1 }
        host.registry.unbindButton(withTag: Part.sometimes)
        apply(true, to: host)
        host.registry.button(withTag: Part.sometimes)?.sendActions(for: .touchUpInside)

        #expect(configured == 0)
        #expect(taps == 1)
    }

    @Test("unbindView leaves an already attached action alone, so a live button keeps working")
    func unbindViewDoesNotUndo() {
        let host = host()
        var taps = 0
        let bindingKey = "live"

        host.registry.bindAction(withTag: Part.always, bindingKey: bindingKey) { _ in taps += 1 }
        apply(false, to: host)
        host.registry.unbindView(withTag: Part.always, bindingKey: bindingKey)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 1)
    }
}

@MainActor
@Suite("Binding events")
struct FLBindingEventTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = Row(showsOptional: false).node
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

        host.registry.bindAction(withTag: Part.always, for: [.touchDown, .touchUpInside]) { received.append($0) }

        let button = host.registry.button(withTag: Part.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == [.touchDown, .touchUpInside])
    }

    @Test("allEvents resolves to the concrete events, not the raw mask")
    func allEventsResolves() {
        let host = hosted()
        var received: [UIControl.Event] = []

        host.registry.bindAction(withTag: Part.always, for: .allEvents) { received.append($0) }
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchDragExit)

        #expect(received == [.touchDragExit])
    }

    @Test("rebinding with a narrower mask detaches the events it dropped")
    func rebindingNarrowsTheMask() {
        let host = hosted()
        var received: [UIControl.Event] = []

        host.registry.bindAction(withTag: Part.always, for: [.touchDown, .touchUpInside]) { received.append($0) }
        host.registry.bindAction(withTag: Part.always, for: .touchUpInside) { received.append($0) }

        let button = host.registry.button(withTag: Part.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == [.touchUpInside])
    }

    @Test("unbinding detaches every event the binding covered")
    func unbindingACompoundMask() {
        let host = hosted()
        var received = 0

        host.registry.bindAction(withTag: Part.always, for: [.touchDown, .touchUpInside]) { _ in received += 1 }
        host.registry.unbindAction(withTag: Part.always)

        let button = host.registry.button(withTag: Part.always)

        button?.sendActions(for: .touchDown)
        button?.sendActions(for: .touchUpInside)

        #expect(received == 0)
    }
}

@MainActor
@Suite("Unbinding everything")
struct FLUnbindAllTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = Row(showsOptional: true).node
        let layout = node.layout(in: FLContext(width: 300))

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        return host
    }

    @Test("unbindAll(withTag:) stops a control that is already wired")
    func unbindAllDetachesLiveActions() {
        let host = hosted()
        var taps = 0

        host.registry.bindAction(withTag: Part.always) { _ in taps += 1 }
        host.registry.unbindAll(withTag: Part.always)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 0)
    }

    @Test("unbindAll(withTag:) clears every key on that tag, live or not")
    func unbindAllClearsEveryKey() {
        let host = hosted()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: Part.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: Part.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.unbindAll(withTag: Part.always)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 0)
        #expect(navigation == 0)
    }

    @Test("unbindAll() reaches every tag")
    func unbindAllAcrossTags() {
        let host = hosted()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: Part.always) { _ in always += 1 }
        host.registry.bindAction(withTag: Part.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll()
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: Part.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 0)
    }

    @Test("unbindAll(withTag:) leaves other tags wired")
    func unbindAllIsPerTag() {
        let host = hosted()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: Part.always) { _ in always += 1 }
        host.registry.bindAction(withTag: Part.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll(withTag: Part.always)
        host.registry.button(withTag: Part.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: Part.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 1)
    }
}
