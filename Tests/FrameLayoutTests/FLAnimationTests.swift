import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Scoped animation")
struct FLAnimationTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted(_ row: AnimationRow) -> FLHost<AnimationRow> {
        let host = FLHost<AnimationRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(row, to: host)

        return host
    }

    private func apply(_ row: AnimationRow, to host: FLHost<AnimationRow>) {
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
        let host = hosted(AnimationRow(height: 40, animation: .linear(0.2)))

        UIView.animate(withDuration: 1) {
            self.apply(AnimationRow(height: 90, animation: .linear(0.2)), to: host)
        }

        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.animated)) == 0.2)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.plain)) == 1)
    }

    @Test("without a scope the subtree inherits the surrounding animation")
    func withoutScopeInherits() {
        let host = hosted(AnimationRow(height: 40, animation: nil))

        UIView.animate(withDuration: 1) {
            self.apply(AnimationRow(height: 90, animation: nil), to: host)
        }

        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.animated)) == 1)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.plain)) == 1)
    }

    @Test("a scope animates on its own, with nothing animating around it")
    func scopeAnimatesWithoutAnOuterBlock() {
        let host = hosted(AnimationRow(height: 40, animation: .linear(0.25)))

        apply(AnimationRow(height: 90, animation: .linear(0.25)), to: host)

        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.animated)) == 0.25)
        #expect(frameAnimationDuration(of: host.registry.view(withTag: AnimationPart.plain)) == nil)
    }

    @Test("the first apply does not animate, so nothing flies in from zero")
    func firstApplyIsSuppressed() {
        let host = FLHost<AnimationRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()

        UIView.animate(withDuration: 1) {
            self.apply(AnimationRow(height: 40, animation: .linear(0.2)), to: host)
        }

        #expect(host.registry.view(withTag: AnimationPart.animated)?.layer.animationKeys() == nil)
        #expect(host.registry.view(withTag: AnimationPart.plain)?.layer.animationKeys() == nil)
    }

    @Test("an unchanged frame does not animate")
    func unchangedFramesDoNotAnimate() {
        let host = hosted(AnimationRow(height: 40, animation: .linear(0.2)))

        apply(AnimationRow(height: 40, animation: .linear(0.2)), to: host)

        #expect(host.registry.view(withTag: AnimationPart.animated)?.layer.animationKeys() == nil)
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
