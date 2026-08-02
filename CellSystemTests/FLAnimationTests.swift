import Testing
import UIKit

@testable import CellSystem

private enum Part: Hashable, Sendable {
    case plain
    case animated
}

private struct Row: FLView {
    let height: CGFloat
    let animation: FLAnimation?

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 4) {
            FLColor(.systemGray4)
                .frame(width: 100, height: height)
                .tag(Part.plain)

            FLColor(.systemBlue)
                .frame(width: 100, height: height)
                .tag(Part.animated)
                .animation(animation)
        }
    }
}

@MainActor
@Suite("Scoped animation")
struct FLAnimationTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted(_ row: Row) -> FLHost<Row> {
        let host = FLHost<Row>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(row, to: host)

        return host
    }

    private func apply(_ row: Row, to host: FLHost<Row>) {
        let node = row.node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
    }

    private func frameAnimationDuration(of view: UIView?) -> TimeInterval? {
        guard let view, let key = view.layer.animationKeys()?.first else { return nil }

        return view.layer.animation(forKey: key)?.duration
    }

    @Test("an animated subtree overrides the surrounding duration")
    func scopeOverridesOuterDuration() {
        let host = hosted(Row(height: 40, animation: .linear(0.2)))

        UIView.animate(withDuration: 1) {
            self.apply(Row(height: 90, animation: .linear(0.2)), to: host)
        }

        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.animated)) == 0.2)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.plain)) == 1)
    }

    @Test("without a scope the subtree inherits the surrounding animation")
    func withoutScopeInherits() {
        let host = hosted(Row(height: 40, animation: nil))

        UIView.animate(withDuration: 1) {
            self.apply(Row(height: 90, animation: nil), to: host)
        }

        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.animated)) == 1)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.plain)) == 1)
    }

    @Test("a scope animates on its own, with nothing animating around it")
    func scopeAnimatesWithoutAnOuterBlock() {
        let host = hosted(Row(height: 40, animation: .linear(0.25)))

        apply(Row(height: 90, animation: .linear(0.25)), to: host)

        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.animated)) == 0.25)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: Part.plain)) == nil)
    }

    @Test("the first apply does not animate, so nothing flies in from zero")
    func firstApplyIsSuppressed() {
        let host = FLHost<Row>()

        window.addSubview(host)
        window.makeKeyAndVisible()

        UIView.animate(withDuration: 1) {
            self.apply(Row(height: 40, animation: .linear(0.2)), to: host)
        }

        #expect(host.registry.view(withTag: Part.animated)?.layer.animationKeys() == nil)
        #expect(host.registry.view(withTag: Part.plain)?.layer.animationKeys() == nil)
    }

    @Test("an unchanged frame does not animate")
    func unchangedFramesDoNotAnimate() {
        let host = hosted(Row(height: 40, animation: .linear(0.2)))

        apply(Row(height: 40, animation: .linear(0.2)), to: host)

        #expect(host.registry.view(withTag: Part.animated)?.layer.animationKeys() == nil)
    }

    @Test("animation does not change layout")
    func animationIsLayoutNeutral() {
        let plain = FLColor(.red).frame(width: 40, height: 20)
        let animated = plain.animation(.easeInOut(0.3))
        let context = FLContext(width: 300)

        #expect(animated.layout(in: context).size == plain.layout(in: context).size)
    }

    @Test("the animation takes part in node equality")
    func animationAffectsIdentity() {
        let base = FLColor(.red).frame(width: 10, height: 10)

        #expect(base.animation(.linear(0.2)) == base.animation(.linear(0.2)))
        #expect(base.animation(.linear(0.2)) != base.animation(.linear(0.4)))
        #expect(base.animation(nil) != base.animation(.linear(0.2)))
    }

    @Test("a spring is described as a value like any other timing")
    func springIsAValue() {
        let spring = FLAnimation.spring(0.5, damping: 0.7, initialVelocity: 0.1)

        #expect(spring.timing.spring?.damping == 0.7)
        #expect(spring.timing.spring?.initialVelocity == 0.1)
        #expect(FLAnimation.linear(0.2).timing.spring == nil)
        #expect(spring == FLAnimation.spring(0.5, damping: 0.7, initialVelocity: 0.1))
    }
}

private struct ValueRow: FLView {
    let height: CGFloat
    let tracked: Int

    var body: some FLNode {
        FLColor(.systemBlue)
            .frame(width: 100, height: height)
            .tag(Part.animated)
            .animation(.linear(0.3), value: tracked)
    }
}

@MainActor
@Suite("Animation scoped to a value")
struct FLAnimationValueTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<ValueRow> {
        let host = FLHost<ValueRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(height: 40, tracked: 0, to: host)

        return host
    }

    private func apply(height: CGFloat, tracked: Int, to host: FLHost<ValueRow>) {
        let node = ValueRow(height: height, tracked: tracked).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
    }

    private func animation(in host: FLHost<ValueRow>) -> CAAnimation? {
        guard let view = host.registry.view(withTag: Part.animated),
              let key = view.layer.animationKeys()?.first else { return nil }

        return view.layer.animation(forKey: key)
    }

    @Test("a change to the tracked value animates")
    func trackedChangeAnimates() {
        let host = hosted()

        apply(height: 90, tracked: 1, to: host)

        #expect(animation(in: host)?.duration == 0.3)
    }

    @Test("a layout change with the value unchanged does not animate")
    func untrackedChangeDoesNotAnimate() {
        let host = hosted()

        apply(height: 90, tracked: 0, to: host)

        #expect(animation(in: host) == nil)
    }

    @Test("the tracked value gates each apply independently")
    func gatingIsPerApply() {
        let host = hosted()

        apply(height: 90, tracked: 1, to: host)
        #expect(animation(in: host)?.duration == 0.3)

        clearAnimations(in: host)
        apply(height: 140, tracked: 1, to: host)
        #expect(animation(in: host) == nil)

        clearAnimations(in: host)
        apply(height: 200, tracked: 2, to: host)
        #expect(animation(in: host)?.duration == 0.3)
    }

    private func clearAnimations(in host: FLHost<ValueRow>) {
        host.registry.view(withTag: Part.animated)?.layer.removeAllAnimations()
    }

    @Test("the tracked value takes part in node equality")
    func valueAffectsIdentity() {
        let base = FLColor(.red).frame(width: 10, height: 10)

        #expect(base.animation(.linear(0.2), value: 1) == base.animation(.linear(0.2), value: 1))
        #expect(base.animation(.linear(0.2), value: 1) != base.animation(.linear(0.2), value: 2))
    }
}

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
