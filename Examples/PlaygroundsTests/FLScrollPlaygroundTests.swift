import Testing
import UIKit

@testable import FrameLayout
@testable import Playgrounds

@MainActor
@Suite("Scroll playground")
struct FLScrollPlaygroundTests {
    private let context = FLContext(width: 320)

    @Test("the chip row hugs its content height and scrolls horizontally")
    func chipRowMeasures() {
        let layout = DemoChipRow(messageID: "m1", showsIndicators: false).node.layout(in: context)

        #expect(layout.size.height > 20)
        #expect(layout.size.height < 60)
        #expect(layout.size.width <= 320)
    }

    @Test("the capped body reserves the cap no matter how much content there is")
    func cappedBodyReservesTheCap() {
        let few = DemoScrollableBody(id: "m1", paragraphs: 2, maximumHeight: 160).node.layout(in: context)
        let many = DemoScrollableBody(id: "m1", paragraphs: 12, maximumHeight: 160).node.layout(in: context)

        #expect(many.size.height == 160)
        #expect(many.size.height >= few.size.height)
    }

    @Test("the unbounded body grows with its content instead of scrolling")
    func unboundedBodyGrows() {
        let two = DemoUnboundedBody(paragraphs: 2).node.layout(in: context).size.height
        let six = DemoUnboundedBody(paragraphs: 6).node.layout(in: context).size.height

        #expect(six > two)
    }

    @Test("the gallery reserves one page no matter how many photos it holds")
    func galleryReservesOnePage() {
        let pageSize = CGSize(width: 320, height: 150)
        let layout = Self.gallery(opensAt: "photo-0", pageSize: pageSize).node.layout(in: context)

        #expect(layout.size == pageSize)
    }

    @Test("it opens at the anchored photo, and the id survives a photo prepended before it")
    func galleryOpensAtItsPhoto() {
        let host = FLHost<DemoPagedGallery>()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 320))

        window.addSubview(host)
        window.makeKeyAndVisible()

        func open(_ visit: String, prepending prefix: [String]) {
            let content = Self.gallery(
                visit: visit,
                names: prefix + Self.names,
                opensAt: "photo-3",
                pageSize: CGSize(width: 320, height: 150)
            )
            let layout = content.node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: content.node, layout: layout)
            host.layoutIfNeeded()
        }

        func offset() -> CGFloat? {
            host.registry.view(withTag: DemoScrollPart.gallery("visit-1"), as: UIScrollView.self)?.contentOffset.x
        }

        open("visit-0", prepending: [])

        #expect(
            host.registry
                .view(withTag: DemoScrollPart.gallery("visit-0"), as: UIScrollView.self)?
                .contentOffset.x == 960
        )

        open("visit-1", prepending: ["photo-new"])

        #expect(offset() == 1280)
    }

    @Test("the strip hugs its thumbnails and the alignment moves where the anchor lands")
    func stripAlignmentMovesTheOffset() {
        let host = FLHost<DemoThumbnailStrip>()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 320))

        window.addSubview(host)
        window.makeKeyAndVisible()

        func open(_ visit: String, alignment: FLAlignment) -> CGFloat? {
            let content = DemoThumbnailStrip(
                visit: visit,
                photos: DemoPagedGallery.photos(from: Self.names),
                opensAt: "photo-3",
                alignment: alignment,
                thumbnail: 72
            )
            let layout = content.node.layout(in: context)

            host.frame = CGRect(origin: .zero, size: layout.size)
            host.apply(node: content.node, layout: layout)
            host.layoutIfNeeded()

            return host.registry
                .view(withTag: DemoScrollPart.strip(visit), as: UIScrollView.self)?
                .contentOffset.x
        }

        #expect(open("visit-0", alignment: .topLeading) == 240)
        #expect(open("visit-1", alignment: .center) == 116)
    }
}

private extension FLScrollPlaygroundTests {
    static let names = (0..<8).map { "photo-\($0)" }

    static func gallery(
        visit: String = "visit-0",
        names: [String] = names,
        opensAt: String,
        pageSize: CGSize
    ) -> DemoPagedGallery {
        DemoPagedGallery(
            visit: visit,
            photos: DemoPagedGallery.photos(from: names),
            opensAt: opensAt,
            pageSize: pageSize
        )
    }
}
