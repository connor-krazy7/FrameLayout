import Testing
import UIKit

@testable import FrameLayout

private enum RowPart: Hashable, Sendable {
    case avatar
    case bubble
    case retry
}

private struct Row: FLView {
    let hasFailed: Bool

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 8) {
            FLColor(.systemGray4)
                .frame(width: 32, height: 32)
                .tag(RowPart.avatar)

            FLVStack(alignment: .leading, spacing: 4) {
                FLColor(.systemBlue)
                    .frame(width: 200, height: 40)
                    .tag(RowPart.bubble)

                if hasFailed {
                    FLColor(.systemRed)
                        .frame(width: 60, height: 20)
                        .tag(RowPart.retry)
                }
            }
        }
    }
}

@MainActor
@Suite("Tags")
struct FLTagTests {
    private func hosted(_ row: Row, width: CGFloat = 300) -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = row.node
        let layout = node.layout(in: FLContext(width: width))

        host.frame = CGRect(origin: .zero, size: CGSize(width: width, height: layout.size.height))
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("a tag does not change layout")
    func taggingIsLayoutNeutral() {
        let plain = FLColor(.red).frame(width: 40, height: 20)
        let identified = plain.tag(RowPart.avatar)
        let context = FLContext(width: 300)

        #expect(identified.layout(in: context).size == plain.layout(in: context).size)
    }

    @Test("the host registers every tagged part")
    func registryFindsParts() {
        let host = hosted(Row(hasFailed: true))

        #expect(host.registry.count == 3)
        #expect(host.registry.containsView(withTag: RowPart.avatar))
        #expect(host.registry.containsView(withTag: RowPart.bubble))
        #expect(host.registry.containsView(withTag: RowPart.retry))
    }

    @Test("an unknown tag resolves to nothing")
    func unknownTag() {
        let host = hosted(Row(hasFailed: false))

        #expect(host.registry.view(withTag: RowPart.retry) == nil)
        #expect(host.registry.view(withTag: "avatar") == nil)
    }

    @Test("a registered view sits where the layout put it")
    func registeredViewHasTheExpectedFrame() {
        let host = hosted(Row(hasFailed: false))
        let avatar = host.registry.view(withTag: RowPart.avatar)
        let bubble = host.registry.view(withTag: RowPart.bubble)

        #expect(avatar?.bounds.size == CGSize(width: 32, height: 32))
        #expect(bubble?.bounds.size == CGSize(width: 200, height: 40))
        #expect(avatar?.convert(CGPoint.zero, to: host) == CGPoint(x: 0, y: 0))
        #expect(bubble?.convert(CGPoint.zero, to: host) == CGPoint(x: 40, y: 0))
    }

    @Test("a part inside an inactive branch is not registered")
    func conditionalPartIsAbsent() {
        let absent = hosted(Row(hasFailed: false))
        let present = hosted(Row(hasFailed: true))

        #expect(absent.registry.count == 2)
        #expect(absent.registry.containsView(withTag: RowPart.retry) == false)
        #expect(present.registry.containsView(withTag: RowPart.retry))
    }

    @Test("reapplying refreshes the registry rather than accumulating")
    func registryIsRebuiltOnApply() {
        let host = hosted(Row(hasFailed: true))
        let node = Row(hasFailed: false).node

        #expect(host.registry.count == 3)

        host.apply(node: node, layout: node.layout(in: FLContext(width: 300)))
        host.layoutIfNeeded()

        #expect(host.registry.count == 2)
        #expect(host.registry.containsView(withTag: RowPart.retry) == false)
    }

    @Test("a tag takes part in node equality")
    func tagAffectsNodeIdentity() {
        let base = FLColor(.red).frame(width: 10, height: 10)

        #expect(base.tag(RowPart.avatar) == base.tag(RowPart.avatar))
        #expect(base.tag(RowPart.avatar) != base.tag(RowPart.bubble))
    }

    @Test("a tagged part stays touch-transparent until something is attached")
    func taggingAloneDoesNotClaimTouches() {
        let host = hosted(Row(hasFailed: false))
        let insideAvatar = CGPoint(x: 16, y: 16)

        #expect(host.hitTest(insideAvatar, with: nil) is FLColorView)
    }

    @Test("a touch inside a tagged part lands within its subtree, so an attached recogniser fires")
    func taggedPartIsInTheTouchChain() {
        let host = hosted(Row(hasFailed: false))
        let bubble = host.registry.view(withTag: RowPart.bubble)
        let hit = host.hitTest(CGPoint(x: 140, y: 20), with: nil)

        #expect(hit is FLColorView)
        #expect(hit?.isDescendant(of: bubble ?? host) == true)
    }

    @Test("a tagged part claims the touch itself once a recogniser is attached and nothing inside wants it")
    func attachedRecogniserClaimsTouches() {
        let node = FLSpacer()
            .frame(width: 100, height: 40)
            .tag(RowPart.bubble)
        let host = FLHostView<FLTagged<FLFrame<FLSpacer>, RowPart>>()
        let layout = node.layout(in: FLContext(width: 100, height: 40))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        let inside = CGPoint(x: 50, y: 20)
        let identified = host.registry.view(withTag: RowPart.bubble)

        #expect(host.hitTest(inside, with: nil) === host)

        identified?.addGestureRecognizer(UITapGestureRecognizer())

        #expect(host.hitTest(inside, with: nil) === identified)
    }

    @Test("wrappers around a tagged part still pass touches through")
    func wrappersStayTransparent() {
        let node = FLColor(.red)
            .frame(width: 20, height: 20)
            .tag(RowPart.avatar)
            .padding(30)
        let host = FLHostView<FLPadded<FLTagged<FLFrame<FLColor>, RowPart>>>()
        let layout = node.layout(in: FLContext(width: 80, height: 80))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        #expect(host.hitTest(CGPoint(x: 4, y: 4), with: nil) === host)
    }

    @Test("the playground row registers the parts its preview wires up")
    func playgroundRowRegistersParts() {
        let host = FLHost<FixtureRow>()
        let row = FixtureRow(item: FixtureItem.sample)
        let node = row.node
        let layout = node.layout(in: FLContext(width: 390))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        #expect(host.registry.containsView(withTag: FixturePart.avatar(FixtureItem.sample.id)))
        #expect(host.registry.containsView(withTag: FixturePart.title(FixtureItem.sample.id)))
        #expect(host.registry.containsView(withTag: FixturePart.detail(FixtureItem.sample.id)))
        #expect(host.registry.containsView(withTag: FixturePart.flag(FixtureItem.sample.id)) == false)
    }

    @Test("the playground row gains and loses parts with its state")
    func playgroundRowFollowsState() {
        let host = FLHost<FixtureRow>()

        func apply(replyingTo: String?, hasFailed: Bool) {
            let node = FixtureRow(item: FixtureItem.sample.with(detail: replyingTo).with(isFlagged: hasFailed)).node
            let layout = node.layout(in: FLContext(width: 390))

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(replyingTo: nil, hasFailed: true)

        #expect(host.registry.containsView(withTag: FixturePart.detail(FixtureItem.sample.id)) == false)
        #expect(host.registry.containsView(withTag: FixturePart.flag(FixtureItem.sample.id)))

        apply(replyingTo: "Replying to Ann", hasFailed: false)

        #expect(host.registry.containsView(withTag: FixturePart.detail(FixtureItem.sample.id)))
        #expect(host.registry.containsView(withTag: FixturePart.flag(FixtureItem.sample.id)) == false)
    }
}
