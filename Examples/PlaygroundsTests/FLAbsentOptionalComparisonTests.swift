import SwiftUI
import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

/// Backs `FLAbsentOptionalComparison` by asserting what its captions claim, in both of the readings the
/// demo shows: hosted alone, where the modifiers around an absent optional still resolve, and inside a
/// stack, where the child gets no slot. The two disagree by design.
///
/// Geometry only — no row contains text, so the sizes match exactly and nothing needs a tolerance. What
/// it leaves open: where a surviving box is drawn. Every number here is a size.
@MainActor
@Suite("Absent optional comparison")
struct FLAbsentOptionalComparisonTests {
    private let width = FLAbsentOptionalSamples.previewWidth
    private let pinned = FLAbsentOptionalSamples.pinned
    private let inset = FLAbsentOptionalSamples.inset
    private let swatch = FLAbsentOptionalSamples.swatch
    private let spacing = FLAbsentOptionalSamples.spacing

    private var absentNode: FLOptional<FLFrame<FLColor>> { FLAbsentOptionalSamples.node(false) }
    private var absentView: some View { FLAbsentOptionalSamples.view(false) }

    private func alone(_ node: some FLNode) -> CGSize {
        node.layout(in: FLContext(width: width)).size
    }

    private func alone(_ view: some View) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity))
    }

    private func stacked(_ node: some FLNode) -> CGFloat {
        FLAbsentOptionalSamples.stackNode(node).layout(in: FLContext(width: width)).size.height
    }

    private func stacked(_ view: some View) -> CGFloat {
        UIHostingController(rootView: FLAbsentOptionalSamples.stackView(view))
            .sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity)).height
    }

    /// Two swatches and one spacing gap — the height the stack rows must come back to.
    private var swatchesAlone: CGFloat { swatch * 2 + spacing }

    @Test("every row of the demo agrees with SwiftUI, hosted alone and in a stack")
    func rowsAgree() {
        #expect(alone(absentNode) == alone(absentView))
        #expect(alone(absentNode.padding(inset)) == alone(absentView.padding(inset)))
        #expect(
            alone(absentNode.frame(width: pinned, height: pinned))
                == alone(absentView.frame(width: pinned, height: pinned))
        )
        #expect(alone(absentNode.frame(maxWidth: pinned)) == alone(absentView.frame(maxWidth: pinned)))

        #expect(stacked(absentNode) == stacked(absentView))
        #expect(stacked(absentNode.padding(inset)) == stacked(absentView.padding(inset)))
        #expect(
            stacked(absentNode.frame(width: pinned, height: pinned))
                == stacked(absentView.frame(width: pinned, height: pinned))
        )
        #expect(
            stacked(absentNode.padding(inset).background(.systemGreen))
                == stacked(absentView.padding(inset).background(Color.green))
        )
    }

    @Test("hosted alone, the modifiers resolve around the absent child")
    func aloneResolvesTheModifiers() {
        #expect(alone(absentNode) == .zero)
        #expect(alone(absentNode.padding(inset)) == CGSize(width: inset * 2, height: inset * 2))
        #expect(alone(absentNode.frame(width: pinned, height: pinned)) == CGSize(width: pinned, height: pinned))
        #expect(alone(absentNode.frame(maxWidth: pinned)) == CGSize(width: pinned, height: 0))
    }

    @Test("in a stack, none of them reserve anything")
    func stackedReservesNothing() {
        #expect(stacked(absentNode) == swatchesAlone)
        #expect(stacked(absentNode.padding(inset)) == swatchesAlone)
        #expect(stacked(absentNode.frame(width: pinned, height: pinned)) == swatchesAlone)
        #expect(stacked(absentNode.padding(inset).background(.systemGreen)) == swatchesAlone)
    }

    @Test("with the condition on, the slot and its spacing come back")
    func presentKeepsItsSlot() {
        let present = FLAbsentOptionalSamples.node(true)

        #expect(stacked(present) == stacked(FLAbsentOptionalSamples.view(true)))
        #expect(stacked(present) == swatch * 3 + spacing * 2)
    }
}
