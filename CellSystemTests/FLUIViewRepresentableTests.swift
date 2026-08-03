import Testing
import UIKit

@testable import CellSystem

@MainActor
final class RepresentableSpy {
    private static var spies: [String: RepresentableSpy] = [:]

    static func spy(_ id: String) -> RepresentableSpy {
        if let existing = spies[id] { return existing }

        let spy = RepresentableSpy()

        spies[id] = spy

        return spy
    }

    var made = 0
    var updates: [String?] = []
    var detached = 0
}

private struct SpyRepresentable: FLUIViewRepresentable {
    let id: String
    let payload: String
    let reserved: CGSize

    func size(in context: FLContext) -> CGSize {
        CGSize(
            width: context.width.resolved(ideal: reserved.width),
            height: context.height.resolved(ideal: reserved.height)
        )
    }

    func makeView() -> UILabel {
        RepresentableSpy.spy(id).made += 1

        return UILabel()
    }

    func update(_ view: UILabel, previous: SpyRepresentable?, context: FLRenderContext) {
        RepresentableSpy.spy(id).updates.append(previous?.payload)

        view.text = payload
    }

    func onDetach(_ view: UILabel) {
        RepresentableSpy.spy(id).detached += 1
    }
}

private struct Row: FLView {
    let id: String
    let payload: String
    let showsPhoto: Bool

    var body: some FLNode {
        FLVStack(spacing: 4) {
            FLText("caption").font(.systemFont(ofSize: 12))

            if showsPhoto {
                SpyRepresentable(id: id, payload: payload, reserved: CGSize(width: 90, height: 60))
                    .frame(width: 90, height: 60)
                    .tag("photo")
            }
        }
    }
}

@MainActor
@Suite("UIView representable")
struct FLUIViewRepresentableTests {
    private let context = FLContext(width: 320)

    private func host(_ row: Row, in window: UIWindow) -> FLHost<Row> {
        let host = FLHost<Row>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(row, to: host)

        return host
    }

    private func apply(_ row: Row, to host: FLHost<Row>) {
        let node = row.node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
    }

    private func makeWindow() -> UIWindow {
        UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }

    @Test("the node declares the size, so layout stays a pure function of node and context")
    func sizeComesFromTheNode() {
        let content = SpyRepresentable(id: "size", payload: "x", reserved: CGSize(width: 120, height: 80))

        #expect(content.flNode.layout(in: FLContext(width: .unspecified)).size == CGSize(width: 120, height: 80))
        #expect(content.flNode.layout(in: FLContext(width: 40)).size.width == 40)
        #expect(RepresentableSpy.spy("size").made == 0)
    }

    @Test("equal nodes are equal and hash alike, so the layout cache can key on them")
    func equalityHolds() {
        let first = SpyRepresentable(id: "eq", payload: "x", reserved: CGSize(width: 10, height: 10)).flNode
        let second = SpyRepresentable(id: "eq", payload: "x", reserved: CGSize(width: 10, height: 10)).flNode
        let different = SpyRepresentable(id: "eq", payload: "y", reserved: CGSize(width: 10, height: 10)).flNode

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first != different)
    }

    @Test("the view is made once and reused across applies")
    func viewIsMadeOnce() {
        let window = makeWindow()
        let host = host(Row(id: "reuse", payload: "one", showsPhoto: true), in: window)

        apply(Row(id: "reuse", payload: "two", showsPhoto: true), to: host)
        apply(Row(id: "reuse", payload: "three", showsPhoto: true), to: host)

        #expect(RepresentableSpy.spy("reuse").made == 1)
        #expect(RepresentableSpy.spy("reuse").updates.count == 3)
    }

    @Test("previous is nil on the first update and the prior content afterwards")
    func previousTracksTheLastContent() {
        let window = makeWindow()
        let host = host(Row(id: "previous", payload: "one", showsPhoto: true), in: window)

        apply(Row(id: "previous", payload: "two", showsPhoto: true), to: host)

        #expect(RepresentableSpy.spy("previous").updates == [nil, "one"])
    }

    @Test("the hosted view fills the box the layout reserved")
    func hostedViewFillsTheBox() {
        let window = makeWindow()
        let host = host(Row(id: "box", payload: "one", showsPhoto: true), in: window)
        let label = host.registry.label(withTag: "photo")

        #expect(label?.text == "one")
        #expect(label?.bounds.size == CGSize(width: 90, height: 60))
    }

    @Test("leaving the window tears the view down, and the next appearance starts over")
    func teardownAndRestart() {
        let window = makeWindow()
        let host = host(Row(id: "teardown", payload: "one", showsPhoto: true), in: window)

        apply(Row(id: "teardown", payload: "one", showsPhoto: false), to: host)

        #expect(RepresentableSpy.spy("teardown").detached == 1)

        apply(Row(id: "teardown", payload: "one", showsPhoto: true), to: host)

        #expect(RepresentableSpy.spy("teardown").updates == [nil, nil])
        #expect(RepresentableSpy.spy("teardown").made == 1)
    }

    @Test("the card's declared size mimics its constraints and never under-reserves")
    func declaredSizeMimicsTheConstraints() {
        let subtitles = [
            "short",
            "a subtitle long enough to wrap onto a second line inside the constraint-driven card",
        ]

        for subtitle in subtitles {
            let card = DemoInfoCard(symbol: "person.2.fill", title: "3 reviewers assigned", subtitle: subtitle)
            let declared = card.flNode.layout(in: FLContext(width: 300)).size
            let view = card.makeView()

            card.update(view, previous: nil, context: FLRenderContext())

            let fitting = view.systemLayoutSizeFitting(
                CGSize(width: declared.width, height: 0),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )

            #expect(declared.width == 300)
            #expect(declared.height >= fitting.height)
            #expect(declared.height - fitting.height <= 3)
        }
    }

    @Test("a frame-based injected view sizes itself from its data")
    func frameBasedViewSizesFromData() {
        let members = [
            DemoMember(initials: "AP", color: .systemBlue),
            DemoMember(initials: "KM", color: .systemPink),
            DemoMember(initials: "JR", color: .systemPurple),
        ]
        let stack = DemoAvatarStack(members: members)
        let size = stack.flNode.layout(in: FLContext(width: 300)).size

        #expect(size == CGSize(width: stack.naturalWidth, height: 28))
        #expect(stack.flNode.layout(in: FLContext(width: 30)).size.width == 30)
    }

    @Test("an injected view keeps its touches")
    func injectedViewKeepsTouches() {
        let window = makeWindow()
        let host = host(Row(id: "touches", payload: "one", showsPhoto: true), in: window)
        let label = host.registry.label(withTag: "photo")
        let point = label.map { $0.convert(CGPoint(x: 4, y: 4), to: host) }

        #expect(point != nil)
        #expect(host.hitTest(point.or(.zero), with: nil) != nil)
    }
}
