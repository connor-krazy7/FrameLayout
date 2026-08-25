import Testing
import UIKit

@testable import FrameLayout

private struct ScrollableRow: FLView {
    let id: String
    let rows: Int

    var body: some FLNode {
        FLScroll {
            FLVStack(spacing: 2) {
                FLForEach(Array(0..<rows), id: \.self) { _ in
                    FLColor(.systemBlue).frame(height: 30)
                }
            }
        }
        .initialContentOffset(contentID: id)
        .frame(maxHeight: 90)
        .tag("region")
    }
}

@MainActor
@Suite("Typed bindings")
struct FLTypedBindingTests {
    private let context = FLContext(width: 200)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))

    private func apply(_ row: ScrollableRow, to host: FLHost<ScrollableRow>) {
        let node = row.node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
    }

    @Test("a typed binding reaches a view inside the tagged region")
    func bindingReachesInsideTheRegion() {
        let host = FLHost<ScrollableRow>()
        var bound: UIScrollView?

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindView(withTag: "region", as: UIScrollView.self) { bound = $0 }
        apply(ScrollableRow(id: "a", rows: 6), to: host)

        #expect(bound != nil)
        #expect(bound === host.registry.view(withTag: "region", as: UIScrollView.self))
        #expect(host.registry.view(withTag: "region") is UIScrollView == false)
    }

    @Test("a binding declared once survives re-applies for anything the node does not declare")
    func bindingSurvivesReapplies() {
        let host = FLHost<ScrollableRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindView(withTag: "region", as: UIScrollView.self) { $0.decelerationRate = .fast }
        apply(ScrollableRow(id: "a", rows: 6), to: host)
        apply(ScrollableRow(id: "a", rows: 8), to: host)

        #expect(host.registry.view(withTag: "region", as: UIScrollView.self)?.decelerationRate == .fast)
    }

    @Test("what the node declares wins over a binding that fights it")
    func nodeConfigurationWinsOverBindings() {
        let host = FLHost<ScrollableRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindView(withTag: "region", as: UIScrollView.self) { $0.bounces = false }
        apply(ScrollableRow(id: "a", rows: 6), to: host)

        #expect(host.registry.view(withTag: "region", as: UIScrollView.self)?.bounces == true)
    }

    @Test("a kind the region does not hold never calls the closure")
    func mismatchedKindIsIgnored() {
        let host = FLHost<ScrollableRow>()
        var calls = 0

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindView(withTag: "region", as: UITextView.self) { _ in calls += 1 }
        apply(ScrollableRow(id: "a", rows: 6), to: host)

        #expect(calls == 0)
    }

    @Test("binding a button resolves through a tagged wrapper now, not just a directly registered one")
    func buttonBindingResolvesThroughAWrapper() {
        struct WrappedButton: FLView {
            var body: some FLNode {
                FLButton(tag: "inner") {
                    FLText("tap").padding(6)
                }
                .padding(4)
                .tag("outer")
            }
        }

        let host = FLHost<WrappedButton>()
        var taps = 0

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindAction(withTag: "inner") { _ in taps += 1 }

        let node = WrappedButton().node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
        host.registry.button(withTag: "outer")?.sendActions(for: .touchUpInside)

        #expect(host.registry.button(withTag: "outer") != nil)
        #expect(taps == 1)
    }
}
