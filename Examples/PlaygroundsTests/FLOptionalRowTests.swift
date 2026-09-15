import SwiftUI
import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

/// Backs `FLOptionalRowPlayground` across every combination of its four toggles, since a row that agrees
/// with SwiftUI in one configuration proves nothing about the fifteen others — a leftover inset shows up
/// only when the part carrying it is switched off.
///
/// Heights only, with the 1pt tolerance every `FLText` comparison takes. What it leaves open: horizontal
/// placement inside the row, which no size assertion can see.
@MainActor
@Suite("Optional row")
struct FLOptionalRowTests {
    private let width: CGFloat = 320

    private func models() -> [MessageRowModel] {
        var models: [MessageRowModel] = []

        for mask in 0..<16 {
            var model = MessageRowModel()
            model.showsBadge = mask & 1 != 0
            model.showsAttachment = mask & 2 != 0
            model.showsError = mask & 4 != 0
            model.showsFootnote = mask & 8 != 0
            models.append(model)
        }

        return models
    }

    private func flHeight(_ model: MessageRowModel) -> CGFloat {
        FLMessageRow(model: model).node.layout(in: FLContext(width: width)).size.height
    }

    private func swiftUIHeight(_ model: MessageRowModel) -> CGFloat {
        UIHostingController(rootView: MessageRowView(model: model).frame(width: width))
            .sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity)).height
    }

    @Test("every combination of the four optional parts matches SwiftUI")
    func everyCombinationMatches() {
        for model in models() {
            let fl = flHeight(model)
            let swiftUI = swiftUIHeight(model)

            #expect(
                abs(fl - swiftUI) <= 1,
                "badge \(model.showsBadge), attachment \(model.showsAttachment), error \(model.showsError), footnote \(model.showsFootnote): FL \(fl) against SwiftUI \(swiftUI)"
            )
        }
    }

    /// The regression this row exists for: switching a part off must cost its whole contribution, insets
    /// and spacing included, not just the content inside them.
    @Test("switching a part off removes its padding and its spacing with it")
    func switchingOffRemovesEverything() {
        var full = MessageRowModel()
        var withoutAttachment = full
        withoutAttachment.showsAttachment = false
        var bare = MessageRowModel()
        bare.showsBadge = false
        bare.showsAttachment = false
        bare.showsError = false
        bare.showsFootnote = false
        full.showsBadge = true

        let attachmentCost = flHeight(full) - flHeight(withoutAttachment)

        // 90pt of content, 4pt of top padding, and the 4pt stack gap above it.
        #expect(attachmentCost == 98)
        #expect(abs(flHeight(bare) - swiftUIHeight(bare)) <= 1)
        #expect(flHeight(bare) < flHeight(withoutAttachment))
    }
}
