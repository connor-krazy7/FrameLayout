import Testing
import UIKit

@testable import CellSystem
@testable import FrameLayout

@MainActor
@Suite("Playground representables")
struct DemoRepresentableTests {
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
}
