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

private struct EmptyComposite: FLView {
    let isVisible: Bool

    var body: some FLNode {
        if isVisible {
            FLColor(.red).frame(width: 10, height: 10)
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

    /// The same branch as `stack(includingMiddle:)`, reached as a node rather than written inline.
    @FLNodeBuilder private func absent(_ isVisible: Bool) -> FLOptional<FLFrame<FLColor>> {
        if isVisible {
            FLColor(.green).frame(width: 10, height: 10)
        }
    }

    private func stackThroughNode(includingMiddle includesMiddle: Bool) -> some FLNode {
        FLVStack(spacing: 8) {
            FLColor(.red).frame(width: 10, height: 10)
            absent(includesMiddle)
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

    // MARK: - Reached as a node

    @Test("the same branch reached through a node costs nothing either")
    func absentNodeCostsNothing() {
        #expect(stackThroughNode(includingMiddle: true).layout(in: context).size.height == 46)
        #expect(stackThroughNode(includingMiddle: false).layout(in: context).size.height == 28)
    }

    @Test("a modifier over an absent node is absent too, so the slot never comes back")
    func modifiersStayAbsent() {
        #expect(absent(false).padding(10).isAbsent)
        #expect(absent(false).frame(width: 100, height: 100).isAbsent)
        #expect(absent(false).padding(10).background(.systemGreen).isAbsent)
        #expect(absent(true).padding(10).isAbsent == false)

        let stack = FLVStack(spacing: 8) {
            FLColor(.red).frame(width: 10, height: 10)
            absent(false).padding(10).frame(width: 100, height: 100)
            FLColor(.blue).frame(width: 10, height: 10)
        }

        #expect(stack.layout(in: context).size.height == 28)
    }

    /// The counterpart, and the one a reader is most likely to think is a bug. Elision happens where a
    /// group asks for children, so a chain measured on its own still resolves its modifiers — which is
    /// also what SwiftUI reports for the same chain hosted as a root.
    @Test("outside a group, a modifier over an absent node still resolves")
    func modifiersResolveOutsideAGroup() {
        #expect(absent(false).padding(10).layout(in: context).size == CGSize(width: 20, height: 20))
        #expect(
            absent(false).frame(width: 100, height: 100).layout(in: context).size
                == CGSize(width: 100, height: 100)
        )
    }

    @Test("a composite whose body is absent contributes nothing")
    func absentCompositeCostsNothing() {
        #expect(Branching(showsText: true).node.isAbsent == false)
        #expect(EmptyComposite(isVisible: false).node.isAbsent)

        let stack = FLVStack(spacing: 8) {
            FLColor(.red).frame(width: 10, height: 10)
            EmptyComposite(isVisible: false)
            FLColor(.blue).frame(width: 10, height: 10)
        }

        #expect(stack.layout(in: context).size.height == 28)
    }

    @Test("a node that becomes absent takes its view off screen")
    @MainActor
    func absentNodeRemovesItsView() {
        let host = FLHostView<FLVStack<FLConcat<FLSingle<FLFrame<FLColor>>, FLSingle<FLOptional<FLFrame<FLColor>>>>>>()

        func apply(_ isVisible: Bool) {
            let node = FLVStack(spacing: 8) {
                FLColor(.red).frame(width: 10, height: 10)
                absent(isVisible)
            }

            host.apply(node: node, layout: node.layout(in: context))
            host.layoutIfNeeded()
        }

        apply(true)
        let attached = host.subviews.first?.subviews.count

        apply(false)

        #expect(attached == 2)
        #expect(host.subviews.first?.subviews.count == 1)
    }

}
