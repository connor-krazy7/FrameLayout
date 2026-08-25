import Testing
import UIKit
@testable import FrameLayout

@Suite("FLProposal")
struct FLProposalTests {
    @Test("only an exact proposal carries a value")
    func exactValue() {
        #expect(FLProposal.exact(120).exactValue == 120)
        #expect(FLProposal.unspecified.exactValue == nil)
        #expect(FLProposal.minimum.exactValue == nil)
        #expect(FLProposal.maximum.exactValue == nil)
    }

    // The point of the enum: insetting propagates explicitly rather than relying on
    // `greatestFiniteMagnitude - n == greatestFiniteMagnitude`.
    @Test("insetting narrows an exact proposal and leaves the others alone")
    func insetting() {
        #expect(FLProposal.exact(100).inset(by: 24) == .exact(76))
        #expect(FLProposal.exact(10).inset(by: 24) == .exact(0))
        #expect(FLProposal.unspecified.inset(by: 24) == .unspecified)
        #expect(FLProposal.minimum.inset(by: 24) == .minimum)
        #expect(FLProposal.maximum.inset(by: 24) == .maximum)
    }

    @Test("the CGFloat convenience init maps nil to unspecified")
    func convenienceInit() {
        #expect(FLContext(width: 300).width == .exact(300))
        #expect(FLContext(width: nil).width == .unspecified)
        #expect(FLContext(width: 300).height == .unspecified)
        #expect(FLContext.unspecified.width == .unspecified)
    }

    @Test("clamping only bounds against an exact proposal")
    func clamping() {
        #expect(FLContext(width: 100).clampingWidth(300) == 100)
        #expect(FLContext(width: 400).clampingWidth(300) == 300)
        #expect(FLContext(width: .unspecified).clampingWidth(300) == 300)
        #expect(FLContext(width: .minimum).clampingWidth(300) == 300)
        #expect(FLContext(width: .maximum).clampingWidth(300) == 300)
    }

    @Test("a fill answers the contract on both axes")
    func fillAnswersContract() {
        let fill = FLColor(.red)

        #expect(fill.layout(in: FLContext(width: .exact(120), height: .exact(40))).size == CGSize(width: 120, height: 40))
        #expect(fill.layout(in: FLContext(width: .unspecified, height: .unspecified)).size == .zero)
        #expect(fill.layout(in: FLContext(width: .minimum, height: .minimum)).size == .zero)
        #expect(fill.layout(in: FLContext(width: .maximum, height: .maximum)).size.width == .infinity)
    }

    @Test("padding reports its insets as its own minimum")
    func paddingMinimum() {
        let node = FLColor(.red).padding(10)
        let size = node.layout(in: FLContext(width: .minimum, height: .minimum)).size

        #expect(size == CGSize(width: 20, height: 20))
    }

    @Test("a constrained frame reports its bounds under min and max queries")
    func frameAnswersContract() {
        let node = FLColor(.red).frame(minWidth: 60, maxWidth: 200)

        #expect(node.layout(in: FLContext(width: .minimum)).size.width == 60)
        #expect(node.layout(in: FLContext(width: .maximum)).size.width == 200)
    }
}
