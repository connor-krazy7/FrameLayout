import Testing
import UIKit

@testable import FrameLayout

private struct ChipRow: FLView {
    let id: String
    let count: Int

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack(spacing: 4) {
                FLForEach(Array(0..<count), id: \.self) { index in
                    FLButton(tag: "chip-\(index)") {
                        FLColor(.systemBlue).frame(width: 60, height: 30)
                    }
                }
            }
        }
        .initialContentOffset(forContent: id)
        .scrollIndicators(.hidden)
        .tag("scroll")
    }
}

@MainActor
@Suite("Scroll behaviour")
struct FLScrollBehaviourTests {
    private let context = FLContext(width: 200, height: 30)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 60))

    private func hosted(_ row: ChipRow) -> FLHost<ChipRow> {
        let host = FLHost<ChipRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(row, to: host)

        return host
    }

    private func apply(_ row: ChipRow, to host: FLHost<ChipRow>) {
        let node = row.node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
    }

    private func scrollView(in host: FLHost<ChipRow>) -> UIScrollView? {
        host.registry.view(withTag: "scroll", as: UIScrollView.self)
    }

    @Test("the view's contentSize matches the measured content")
    func contentSizeMatchesTheLayout() {
        let host = hosted(ChipRow(id: "a", count: 8))

        #expect(scrollView(in: host)?.contentSize.width == CGFloat(8 * 60 + 7 * 4))
        #expect(scrollView(in: host)?.bounds.width == 200)
    }

    @Test("configuration reaches the view")
    func configurationIsApplied() {
        let host = hosted(ChipRow(id: "a", count: 8))
        let scroll = scrollView(in: host)

        #expect(scroll?.showsHorizontalScrollIndicator == false)
        #expect(scroll?.contentInsetAdjustmentBehavior == .never)
        #expect(scroll?.delaysContentTouches == false)
    }

    @Test("the offset survives a re-apply that only changes the data")
    func offsetSurvivesDataChanges() {
        let host = hosted(ChipRow(id: "a", count: 8))

        scrollView(in: host)?.contentOffset = CGPoint(x: 120, y: 0)
        apply(ChipRow(id: "a", count: 9), to: host)

        #expect(scrollView(in: host)?.contentOffset.x == 120)
    }

    @Test("a changed reset token puts the offset back to the start")
    func tokenResetsTheOffset() {
        let host = hosted(ChipRow(id: "a", count: 8))

        scrollView(in: host)?.contentOffset = CGPoint(x: 120, y: 0)
        apply(ChipRow(id: "b", count: 8), to: host)

        #expect(scrollView(in: host)?.contentOffset.x == 0)
    }

    @Test("a drag starting on a button can still scroll")
    func dragFromAButtonScrolls() {
        let host = hosted(ChipRow(id: "a", count: 8))
        let scroll = scrollView(in: host)
        let chip = host.registry.button(withTag: "chip-0")

        guard let chip, let scroll else { return #expect(Bool(false), "expected a chip and a scroll view") }

        #expect(scroll.touchesShouldCancel(in: chip))
    }

    @Test("touches reach the content inside the region")
    func touchesReachTheContent() {
        let host = hosted(ChipRow(id: "a", count: 8))
        let hit = host.hitTest(CGPoint(x: 20, y: 15), with: nil)

        #expect(hit != nil)
        #expect(hit is UIScrollView == false)
    }
}
