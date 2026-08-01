import Testing
import UIKit

@testable import CellSystem

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
                .id(RowPart.avatar)

            FLVStack(alignment: .leading, spacing: 4) {
                FLColor(.systemBlue)
                    .frame(width: 200, height: 40)
                    .id(RowPart.bubble)

                if hasFailed {
                    FLColor(.systemRed)
                        .frame(width: 60, height: 20)
                        .id(RowPart.retry)
                }
            }
        }
    }
}

@MainActor
@Suite("Identity")
struct FLIdentityTests {
    private func hosted(_ row: Row, width: CGFloat = 300) -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = row.node
        let layout = node.layout(in: FLContext(width: width))

        host.frame = CGRect(origin: .zero, size: CGSize(width: width, height: layout.size.height))
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("id does not change layout")
    func identityIsLayoutNeutral() {
        let plain = FLColor(.red).frame(width: 40, height: 20)
        let identified = plain.id(RowPart.avatar)
        let context = FLContext(width: 300)

        #expect(identified.layout(in: context).size == plain.layout(in: context).size)
    }

    @Test("the host registers every identified part")
    func registryFindsParts() {
        let host = hosted(Row(hasFailed: true))

        #expect(host.registry.count == 3)
        #expect(host.registry.contains(RowPart.avatar))
        #expect(host.registry.contains(RowPart.bubble))
        #expect(host.registry.contains(RowPart.retry))
    }

    @Test("an unknown id resolves to nothing")
    func unknownIdentifier() {
        let host = hosted(Row(hasFailed: false))

        #expect(host.registry.view(for: RowPart.retry) == nil)
        #expect(host.registry.view(for: "avatar") == nil)
    }

    @Test("a registered view sits where the layout put it")
    func registeredViewHasTheExpectedFrame() {
        let host = hosted(Row(hasFailed: false))
        let avatar = host.registry.view(for: RowPart.avatar)
        let bubble = host.registry.view(for: RowPart.bubble)

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
        #expect(absent.registry.contains(RowPart.retry) == false)
        #expect(present.registry.contains(RowPart.retry))
    }

    @Test("reapplying refreshes the registry rather than accumulating")
    func registryIsRebuiltOnApply() {
        let host = hosted(Row(hasFailed: true))
        let node = Row(hasFailed: false).node

        #expect(host.registry.count == 3)

        host.apply(node: node, layout: node.layout(in: FLContext(width: 300)))
        host.layoutIfNeeded()

        #expect(host.registry.count == 2)
        #expect(host.registry.contains(RowPart.retry) == false)
    }

    @Test("identity takes part in node equality")
    func identityAffectsNodeIdentity() {
        let base = FLColor(.red).frame(width: 10, height: 10)

        #expect(base.id(RowPart.avatar) == base.id(RowPart.avatar))
        #expect(base.id(RowPart.avatar) != base.id(RowPart.bubble))
    }

    @Test("an identified part stays touch-transparent until something is attached")
    func identityAloneDoesNotClaimTouches() {
        let host = hosted(Row(hasFailed: false))
        let insideAvatar = CGPoint(x: 16, y: 16)

        #expect(host.hitTest(insideAvatar, with: nil) is FLColorView)
    }

    @Test("a touch inside an identified part lands within its subtree, so an attached recogniser fires")
    func identifiedPartIsInTheTouchChain() {
        let host = hosted(Row(hasFailed: false))
        let bubble = host.registry.view(for: RowPart.bubble)
        let hit = host.hitTest(CGPoint(x: 140, y: 20), with: nil)

        #expect(hit is FLColorView)
        #expect(hit?.isDescendant(of: bubble ?? host) == true)
    }

    @Test("an identified part claims the touch itself once a recogniser is attached and nothing inside wants it")
    func attachedRecogniserClaimsTouches() {
        let node = FLSpacer()
            .frame(width: 100, height: 40)
            .id(RowPart.bubble)
        let host = FLHostView<FLIdentified<FLFrame<FLSpacer>, RowPart>>()
        let layout = node.layout(in: FLContext(width: 100, height: 40))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        let inside = CGPoint(x: 50, y: 20)
        let identified = host.registry.view(for: RowPart.bubble)

        #expect(host.hitTest(inside, with: nil) === host)

        identified?.addGestureRecognizer(UITapGestureRecognizer())

        #expect(host.hitTest(inside, with: nil) === identified)
    }

    @Test("wrappers around an identified part still pass touches through")
    func wrappersStayTransparent() {
        let node = FLColor(.red)
            .frame(width: 20, height: 20)
            .id(RowPart.avatar)
            .padding(30)
        let host = FLHostView<FLPadded<FLIdentified<FLFrame<FLColor>, RowPart>>>()
        let layout = node.layout(in: FLContext(width: 80, height: 80))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        #expect(host.hitTest(CGPoint(x: 4, y: 4), with: nil) === host)
    }

    @Test("the playground row registers the parts its preview wires up")
    func playgroundRowRegistersParts() {
        let host = FLHost<DemoMessageRow>()
        let row = DemoMessageRow(text: "hello there", replyingTo: "Replying to Ann", hasFailed: false)
        let node = row.node
        let layout = node.layout(in: FLContext(width: 390))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        #expect(host.registry.contains(DemoRowPart.avatar))
        #expect(host.registry.contains(DemoRowPart.bubble))
        #expect(host.registry.contains(DemoRowPart.replyPreview))
        #expect(host.registry.contains(DemoRowPart.retry) == false)
    }

    @Test("the playground row gains and loses parts with its state")
    func playgroundRowFollowsState() {
        let host = FLHost<DemoMessageRow>()

        func apply(replyingTo: String?, hasFailed: Bool) {
            let node = DemoMessageRow(text: "hello there", replyingTo: replyingTo, hasFailed: hasFailed).node
            let layout = node.layout(in: FLContext(width: 390))

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(replyingTo: nil, hasFailed: true)

        #expect(host.registry.contains(DemoRowPart.replyPreview) == false)
        #expect(host.registry.contains(DemoRowPart.retry))

        apply(replyingTo: "Replying to Ann", hasFailed: false)

        #expect(host.registry.contains(DemoRowPart.replyPreview))
        #expect(host.registry.contains(DemoRowPart.retry) == false)
    }
}
