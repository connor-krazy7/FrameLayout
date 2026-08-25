import Testing
import UIKit

@testable import FrameLayout
@testable import Playgrounds

@MainActor
@Suite("Grid playground")
struct FLGridPlaygroundTests {
    private let context = FLContext(width: 320)

    @Test("the photo grid grows a line at a time")
    func photoGridGrowsByLine() {
        let three = DemoPhotoGrid(count: 3, columns: 3, spacing: 4).node.layout(in: context).size.height
        let four = DemoPhotoGrid(count: 4, columns: 3, spacing: 4).node.layout(in: context).size.height
        let six = DemoPhotoGrid(count: 6, columns: 3, spacing: 4).node.layout(in: context).size.height

        #expect(four > three)
        #expect(four == six)
    }

    @Test("a smaller adaptive minimum fits more columns, so the picker gets shorter")
    func adaptiveMinimumChangesTheHeight() {
        let wide = DemoReactionPicker(minimum: 88).node.layout(in: context).size.height
        let narrow = DemoReactionPicker(minimum: 40).node.layout(in: context).size.height

        #expect(narrow < wide)
    }

    @Test("the carousel keeps its bounded height and scrolls horizontally")
    func carouselIsBounded() {
        let layout = DemoStickerCarousel(stickers: 9).node.layout(in: context)

        #expect(layout.size.height == 128)
        #expect(layout.size.width <= 320)
    }

    @Test("the table aligns its label column at a fixed width")
    func tableColumnsAlign() {
        let layout = DemoDetailTable().node.layout(in: context)

        #expect(layout.size.width == 320)
        #expect(layout.size.height > 40)
    }
}
