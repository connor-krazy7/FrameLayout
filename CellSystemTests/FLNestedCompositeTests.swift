import Testing
import UIKit

@testable import CellSystem

@MainActor
@Suite("Nested composites")
struct FLNestedCompositeTests {
    private let context = FLContext(width: 320)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))

    private func message(
        replyContext: DemoReplyContext? = nil,
        photo: DemoPhoto? = nil,
        attachments: Int = 0,
        reactions: Int = 0,
        delivery: DemoDelivery = .sent
    ) -> DemoMessage {
        DemoMessage(
            id: "m1",
            author: DemoAuthor(id: "u1", name: "Ann Petrova", initials: "AP"),
            text: "Every level here is its own FLView.",
            replyContext: replyContext,
            photo: photo,
            attachments: (0..<attachments).map {
                DemoAttachment(id: "a\($0)", symbol: "doc.fill", title: "File \($0)", detail: "1 KB")
            },
            reactions: (0..<reactions).map {
                DemoReactionSummary(id: "r\($0)", emoji: "🎉", count: $0 + 1, isMine: false)
            },
            delivery: delivery
        )
    }

    private func height(_ message: DemoMessage) -> CGFloat {
        DemoNestedMessageRow(message: message).node.layout(in: context).size.height
    }

    private func hosted(_ message: DemoMessage) -> FLHost<DemoNestedMessageRow> {
        let host = FLHost<DemoNestedMessageRow>()
        let node = DemoNestedMessageRow(message: message).node
        let layout = node.layout(in: context)

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("a five-level composite tree measures to something sane")
    func nestedTreeMeasures() {
        let size = DemoNestedMessageRow(message: message()).node.layout(in: context).size

        #expect(size.width > 0)
        #expect(size.height > 40)
        #expect(size.width <= 320)
    }

    @Test("nested data drives the size: each attachment adds height")
    func attachmentsGrowTheBubble() {
        let none = height(message())
        let one = height(message(attachments: 1))
        let two = height(message(attachments: 2))

        #expect(one > none)
        #expect(two - one == one - none)
    }

    @Test("a reply preview only costs height when the data has one")
    func replyContextIsConditional() {
        let without = height(message())
        let with = height(message(replyContext: DemoReplyContext(author: "Ann", snippet: "hi")))

        #expect(with > without)
    }

    @Test("reactions lay out along the footer without changing the bubble")
    func reactionsDoNotResizeTheBubble() {
        let none = hosted(message())
        let several = hosted(message(reactions: 3))

        let bubbleWithout = none.registry.view(withTag: DemoMessagePart.bubble("m1"))?.bounds.size
        let bubbleWith = several.registry.view(withTag: DemoMessagePart.bubble("m1"))?.bounds.size

        #expect(bubbleWithout == bubbleWith)
        #expect(several.contentSize.height >= none.contentSize.height)
    }

    @Test("parts nested three composites deep are still reachable by tag")
    func deeplyNestedPartsAreTagged() {
        let host = hosted(message(delivery: .failed))

        #expect(host.registry.containsView(withTag: DemoMessagePart.avatar("m1")))
        #expect(host.registry.containsView(withTag: DemoMessagePart.bubble("m1")))
        #expect(host.registry.button(withTag: DemoMessagePart.retry("m1")) != nil)
    }

    @Test("the retry button only exists while the message has failed")
    func retryFollowsDelivery() {
        #expect(hosted(message(delivery: .failed)).registry.button(withTag: DemoMessagePart.retry("m1")) != nil)
        #expect(hosted(message(delivery: .sent)).registry.button(withTag: DemoMessagePart.retry("m1")) == nil)
    }

    @Test("a binding declared once survives the retry button coming and going")
    func bindingSurvivesDeliveryChanges() {
        let host = FLHost<DemoNestedMessageRow>()
        var retries = 0

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.registry.bindAction(withTag: DemoMessagePart.retry("m1")) { _ in retries += 1 }

        func apply(_ delivery: DemoDelivery) {
            let node = DemoNestedMessageRow(message: message(delivery: delivery)).node
            let layout = node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()
        }

        apply(.sent)
        apply(.failed)
        host.registry.button(withTag: DemoMessagePart.retry("m1"))?.sendActions(for: .touchUpInside)

        apply(.sent)
        apply(.failed)
        host.registry.button(withTag: DemoMessagePart.retry("m1"))?.sendActions(for: .touchUpInside)

        #expect(retries == 2)
    }

    @Test("equal nested data produces equal nodes, so the cache can key on them")
    func nestedEqualityHolds() {
        let first = DemoNestedMessageRow(message: message(attachments: 2, reactions: 1)).node
        let second = DemoNestedMessageRow(message: message(attachments: 2, reactions: 1)).node
        let different = DemoNestedMessageRow(message: message(attachments: 3, reactions: 1)).node

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first != different)
    }

    @Test("the whole sample conversation lays out")
    func samplesLayOut() {
        for message in DemoMessage.samples {
            let size = DemoNestedMessageRow(message: message).node.layout(in: context).size

            #expect(size.height > 0)
            #expect(size.width <= 320)
        }
    }
}

private struct Plain: FLView {
    var body: some FLNode {
        FLColor(.systemBlue).frame(width: 40, height: 20)
    }
}

@MainActor
@Suite("Modifiers on composites")
struct FLCompositeModifierTests {
    private let context = FLContext(width: 300)

    @Test("a composite takes modifiers without being converted first")
    func compositeTakesModifiers() {
        let padded = Plain().padding(10)
        let node = Plain().node.padding(10)

        #expect(padded.layout(in: context).size == node.layout(in: context).size)
    }

    @Test("modifiers chain on a composite the same way they do on a node")
    func modifiersChain() {
        let chained = Plain()
            .padding(8)
            .background(.systemRed, in: .roundedRectangle(4))
            .opacity(0.5)
            .frame(width: 100, height: 60)

        #expect(chained.layout(in: context).size == CGSize(width: 100, height: 60))
    }

    @Test("a modified composite is still a node the builders accept")
    func modifiedCompositeComposes() {
        let stack = FLVStack(spacing: 4) {
            Plain().padding(6)
            Plain()
        }

        #expect(stack.layout(in: context).size.height == CGFloat(20 + 12 + 4 + 20))
    }

    @Test("tagging a composite registers the view it produced")
    func taggingAComposite() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let host = FLHostView<FLTagged<FLComposed<Plain>, String>>()
        let node = Plain().tag("plain")
        let layout = node.layout(in: context)

        window.addSubview(host)
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        #expect(host.registry.containsView(withTag: "plain"))
    }

    @Test("modifying a composite does not change what it measures")
    func modifyingIsLayoutNeutralWhereItShouldBe() {
        let bare = Plain().node.layout(in: context).size
        let tagged = Plain().tag("plain").layout(in: context).size
        let faded = Plain().opacity(0.3).layout(in: context).size

        #expect(bare == tagged)
        #expect(bare == faded)
    }
}


@MainActor
@Suite("Flexible conversation photo")
struct FLFlexiblePhotoTests {
    private func box(_ pixelSize: CGSize, availableWidth: CGFloat) -> CGSize {
        DemoConversationPhoto(photo: DemoPhoto(id: "p", symbol: "photo.fill", pixelSize: pixelSize))
            .node
            .layout(in: FLContext(width: availableWidth))
            .size
    }

    @Test("a photo wider than the space scales down and keeps its ratio")
    func wideePhotoScalesDown() {
        let reserved = box(CGSize(width: 1600, height: 900), availableWidth: 240)

        #expect(reserved.width == 240)
        #expect(abs(reserved.height - 240 * 900 / 1600) <= 1)
    }

    @Test("a photo smaller than the space is not stretched to fill it")
    func smallPhotoIsNotUpscaled() {
        let reserved = box(CGSize(width: 80, height: 60), availableWidth: 300)

        #expect(reserved.width == 80)
        #expect(reserved.height == 60)
    }

    @Test("a tall photo is capped by height without distorting")
    func tallPhotoIsCappedByHeight() {
        let pixelSize = CGSize(width: 900, height: 1600)
        let reserved = box(pixelSize, availableWidth: 300)
        let ratio = pixelSize.width / pixelSize.height

        #expect(reserved.height <= DemoConversationPhoto.maximumHeight)
        #expect(abs(reserved.width / reserved.height - ratio) < 0.02)
    }

    @Test("the box comes from the known dimensions, so it is reserved before anything loads")
    func boxIsReservedWithoutAnImage() {
        let known = DemoPhoto(id: "p", symbol: "photo.fill", pixelSize: CGSize(width: 1600, height: 900))
        let withSymbol = DemoConversationPhoto(photo: known).node.layout(in: FLContext(width: 240)).size
        let missingSymbol = DemoConversationPhoto(
            photo: DemoPhoto(id: "p", symbol: "not.a.real.symbol", pixelSize: known.pixelSize)
        )
        .node
        .layout(in: FLContext(width: 240))
        .size

        #expect(withSymbol == missingSymbol)
    }

    @Test("a photo grows the bubble, and the tagged box is reachable")
    func photoGrowsTheMessage() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 800))
        let host = FLHost<DemoNestedMessageRow>()

        window.addSubview(host)

        func apply(_ photo: DemoPhoto?) -> CGFloat {
            let message = DemoMessage(
                id: "m1",
                author: DemoAuthor(id: "u1", name: "Ann", initials: "AP"),
                text: "look at this",
                replyContext: nil,
                photo: photo,
                attachments: [],
                reactions: [],
                delivery: .sent
            )
            let node = DemoNestedMessageRow(message: message).node
            let layout = node.layout(in: FLContext(width: 320))

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: node, layout: layout)
            host.layoutIfNeeded()

            return layout.size.height
        }

        let without = apply(nil)

        #expect(host.registry.containsView(withTag: DemoMessagePart.photo("m1")) == false)

        let with = apply(DemoPhoto(id: "p", symbol: "photo.fill", pixelSize: CGSize(width: 1600, height: 900)))

        #expect(with > without)
        #expect(host.registry.view(withTag: DemoMessagePart.photo("m1"))?.bounds.height ?? 0 > 0)
        #expect(host.registry.imageView(withTag: DemoMessagePart.photo("m1")) != nil)
    }
}
