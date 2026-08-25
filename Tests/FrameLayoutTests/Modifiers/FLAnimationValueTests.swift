import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Animation scoped to a value")
struct FLAnimationValueTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<AnimationValueRow> {
        let host = FLHost<AnimationValueRow>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(height: 40, tracked: 0, to: host)

        return host
    }

    private func apply(height: CGFloat, tracked: Int, to host: FLHost<AnimationValueRow>) {
        let node = AnimationValueRow(height: height, tracked: tracked).node
        let layout = node.layout(in: FLContext(width: 300))

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
    }

    private func animation(in host: FLHost<AnimationValueRow>) -> CAAnimation? {
        guard let view = host.registry.view(withTag: AnimationPart.animated),
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

    private func clearAnimations(in host: FLHost<AnimationValueRow>) {
        host.registry.view(withTag: AnimationPart.animated)?.layer.removeAllAnimations()
    }

    @Test("the tracked value takes part in node equality")
    func valueAffectsIdentity() {
        let base = FLColor(.red).frame(width: 10, height: 10)

        #expect(base.animation(.linear(0.2), value: 1) == base.animation(.linear(0.2), value: 1))
        #expect(base.animation(.linear(0.2), value: 1) != base.animation(.linear(0.2), value: 2))
    }
}
