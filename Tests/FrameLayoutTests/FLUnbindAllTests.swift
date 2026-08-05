import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Unbinding everything")
struct FLUnbindAllTests {
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

    @Test("unbindAll(withTag:) stops a control that is already wired")
    func unbindAllDetachesLiveActions() {
        let host = hosted()
        var taps = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in taps += 1 }
        host.registry.unbindAll(withTag: BindingPart.always)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(taps == 0)
    }

    @Test("unbindAll(withTag:) clears every key on that tag, live or not")
    func unbindAllClearsEveryKey() {
        let host = hosted()
        var analytics = 0
        var navigation = 0

        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "analytics") { _ in analytics += 1 }
        host.registry.bindAction(withTag: BindingPart.always, bindingKey: "navigation") { _ in navigation += 1 }
        host.registry.unbindAll(withTag: BindingPart.always)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)

        #expect(analytics == 0)
        #expect(navigation == 0)
    }

    @Test("unbindAll() reaches every tag")
    func unbindAllAcrossTags() {
        let host = hosted()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in always += 1 }
        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll()
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: BindingPart.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 0)
    }

    @Test("unbindAll(withTag:) leaves other tags wired")
    func unbindAllIsPerTag() {
        let host = hosted()
        var always = 0
        var sometimes = 0

        host.registry.bindAction(withTag: BindingPart.always) { _ in always += 1 }
        host.registry.bindAction(withTag: BindingPart.sometimes) { _ in sometimes += 1 }
        host.registry.unbindAll(withTag: BindingPart.always)
        host.registry.button(withTag: BindingPart.always)?.sendActions(for: .touchUpInside)
        host.registry.button(withTag: BindingPart.sometimes)?.sendActions(for: .touchUpInside)

        #expect(always == 0)
        #expect(sometimes == 1)
    }
}
