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
}
