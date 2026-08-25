import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Constraint-driven representables")
struct FLConstraintRepresentableTests {
    private let subtitles = [
        "one line",
        "a subtitle long enough to wrap onto a second line inside a constraint-driven card",
        "a subtitle that keeps going far enough to need a third line of layout inside the card",
    ]

    private func resolvedHeight(_ card: FixtureConstraintCard, width: CGFloat) -> CGFloat {
        let view = card.makeView()

        card.update(view, previous: nil, context: FLRenderContext())

        return view.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
    }

    @Test("a declared size never under-reserves what the constraints resolve to")
    func declaredSizeNeverUnderReserves() {
        for subtitle in subtitles {
            for width in [220, 300, 380] as [CGFloat] {
                let card = FixtureConstraintCard(title: "Constraint-driven card", subtitle: subtitle)
                let declared = card.flNode.layout(in: FLContext(width: width)).size

                #expect(declared.width == width)
                #expect(declared.height >= resolvedHeight(card, width: width))
                #expect(declared.height - resolvedHeight(card, width: width) <= 3)
            }
        }
    }

    @Test("wrapping subtitles grow the declared height")
    func wrappingGrowsTheHeight() {
        let heights = subtitles.map { subtitle in
            FixtureConstraintCard(title: "Constraint-driven card", subtitle: subtitle)
                .flNode
                .layout(in: FLContext(width: 240))
                .size
                .height
        }

        #expect(heights == heights.sorted())
        #expect(heights.first != heights.last)
    }

    @Test("a narrower box wraps more, so it reserves more height")
    func narrowerBoxesReserveMore() {
        let card = FixtureConstraintCard(title: "Constraint-driven card", subtitle: subtitles[1])
        let narrow = card.flNode.layout(in: FLContext(width: 200)).size.height
        let wide = card.flNode.layout(in: FLContext(width: 380)).size.height

        #expect(narrow > wide)
    }
}
