import Testing
import UIKit

@testable import FrameLayout

private struct Branching: FLView {
    let showsText: Bool

    var body: some FLNode {
        if showsText {
            FLColor(.red).frame(width: 30, height: 10)
        } else {
            FLColor(.blue).frame(width: 50, height: 20)
        }
    }
}

@Suite("Conditionals")
struct FLConditionalTests {
    private let context = FLContext(width: 300)

    private func stack(includingMiddle includesMiddle: Bool) -> some FLNode {
        FLVStack(spacing: 8) {
            FLColor(.red).frame(width: 10, height: 10)
            if includesMiddle {
                FLColor(.green).frame(width: 10, height: 10)
            }
            FLColor(.blue).frame(width: 10, height: 10)
        }
    }

    @Test("if/else takes the size of the branch it picked")
    func eitherPicksBranch() {
        #expect(Branching(showsText: true).node.layout(in: context).size == CGSize(width: 30, height: 10))
        #expect(Branching(showsText: false).node.layout(in: context).size == CGSize(width: 50, height: 20))
    }

    @Test("an absent child takes no space and no spacing")
    func absentChildCostsNothing() {
        let withMiddle = stack(includingMiddle: true).layout(in: context).size
        let withoutMiddle = stack(includingMiddle: false).layout(in: context).size

        #expect(withMiddle.height == 46)
        #expect(withoutMiddle.height == 28)
    }

    @Test("an absent child is laid out at zero and does not shift its siblings")
    func absentChildDoesNotShiftSiblings() {
        let includesMiddle = false
        let layout = FLVStack(spacing: 8) {
            FLColor(.red).frame(width: 10, height: 10)
            if includesMiddle {
                FLColor(.green).frame(width: 10, height: 10)
            }
            FLColor(.blue).frame(width: 10, height: 10)
        }
        .layout(in: context)

        #expect(layout.childFrames.count == 2)
        #expect(layout.childFrames[0].minY == 0)
        #expect(layout.childFrames[1].minY == 18)
    }

    @Test("if let contributes its content when the value is there")
    func ifLetBinding() {
        func node(for title: String?) -> some FLNode {
            FLVStack {
                if let title {
                    FLText(title).frame(width: 40, height: 12)
                }
            }
        }

        #expect(node(for: "shown").layout(in: context).size.height == 12)
        #expect(node(for: nil).layout(in: context).size.height == 0)
    }

    @Test("a chain of branches picks exactly one")
    func chainedBranches() {
        func node(first: Bool, second: Bool) -> some FLNode {
            FLVStack {
                if first {
                    FLColor(.red).frame(width: 10, height: 10)
                } else if second {
                    FLColor(.green).frame(width: 10, height: 20)
                } else {
                    FLColor(.blue).frame(width: 10, height: 30)
                }
            }
        }

        #expect(node(first: true, second: true).layout(in: context).size.height == 10)
        #expect(node(first: false, second: true).layout(in: context).size.height == 20)
        #expect(node(first: false, second: false).layout(in: context).size.height == 30)
    }

    @Test("nesting conditionals stays absent unless every condition holds")
    func nestedConditionals() {
        func node(outer: Bool, inner: Bool) -> some FLNode {
            FLVStack {
                if outer {
                    if inner {
                        FLColor(.red).frame(width: 10, height: 10)
                    }
                }
            }
        }

        #expect(node(outer: true, inner: true).layout(in: context).size.height == 10)
        #expect(node(outer: true, inner: false).layout(in: context).size.height == 0)
        #expect(node(outer: false, inner: false).layout(in: context).size.height == 0)
    }

    @Test("an absent branch contributes no children to its group")
    func absentBranchContributesNothing() {
        let present = FLOptionalGroup(wrapped: FLSingle(node: FLColor(.red).frame(width: 10, height: 10)))
        let absent = FLOptionalGroup<FLSingle<FLFrame<FLColor>>>(wrapped: nil)

        #expect(present.childCount == 1)
        #expect(absent.childCount == 0)
        #expect(present.layout(in: context).count == 1)
        #expect(absent.layout(in: context).count == 0)
    }

    @Test("a spacer stays flexible through a conditional")
    func spacerSurvivesConditional() {
        let either = FLEither<FLSpacer, FLColor>.first(FLSpacer())

        #expect(either.isSpacer)
        #expect(FLEither<FLSpacer, FLColor>.second(FLColor(.red)).isSpacer == false)
        #expect(FLOptional(wrapped: FLSpacer()).isSpacer)
    }

    @Test("a conditional spacer still absorbs slack in a bounded stack")
    func conditionalSpacerAbsorbsSlack() {
        let node = FLVStack {
            FLColor(.red).frame(width: 10, height: 10)
            if true {
                FLSpacer()
            }
            FLColor(.blue).frame(width: 10, height: 10)
        }
        let layout = node.layout(in: FLContext(width: 300, height: 100))

        #expect(layout.size.height == 100)
        #expect(layout.childFrames[2].minY == 90)
    }
}
