import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

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
