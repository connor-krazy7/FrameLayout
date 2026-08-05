import Testing
import UIKit

@testable import Playgrounds
@testable import FrameLayout

@MainActor
@Suite("Transition playground")
struct FLTransitionPlaygroundTests {
    private let context = FLContext(width: 320)

    private func collapsing(_ showsRetry: Bool) -> CGFloat {
        CollapsingDemoRow(showsRetry: showsRetry, animation: .linear(0.2)).node.layout(in: context).size.height
    }

    private func conditional(_ showsRetry: Bool) -> CGFloat {
        ConditionalDemoRow(showsRetry: showsRetry).node.layout(in: context).size.height
    }

    @Test("both rows are the same height while the retry is showing")
    func sameHeightWhenShown() {
        #expect(collapsing(true) == conditional(true))
    }

    @Test("collapsing gives back the retry's height but keeps its spacing")
    func collapsingKeepsSpacing() {
        #expect(collapsing(true) - collapsing(false) == 26)
        #expect(collapsing(false) - conditional(false) == 8)
    }

    @Test("removing gives back the height and the spacing")
    func conditionalGivesBackBoth() {
        #expect(conditional(true) - conditional(false) == 34)
    }

    @Test("the retry part is registered while collapsed, and gone when removed")
    func registrationDiffersBetweenTheTwo() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let collapsingHost = FLHost<CollapsingDemoRow>()
        let conditionalHost = FLHost<ConditionalDemoRow>()

        window.addSubview(collapsingHost)
        window.addSubview(conditionalHost)

        let collapsed = CollapsingDemoRow(showsRetry: false, animation: .linear(0.2)).node
        let removed = ConditionalDemoRow(showsRetry: false).node

        collapsingHost.apply(node: collapsed, layout: collapsed.layout(in: context))
        conditionalHost.apply(node: removed, layout: removed.layout(in: context))

        #expect(collapsingHost.registry.containsView(withTag: TransitionDemoPart.retry))
        #expect(conditionalHost.registry.containsView(withTag: TransitionDemoPart.retry) == false)
    }
}
