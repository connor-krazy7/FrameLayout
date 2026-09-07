import Testing
import UIKit

@testable import FrameLayout

/// A host whose height comes from `intrinsicContentSize` is the shape every self-sizing cell and
/// constraint-driven screen uses. `FLTextEditorPlaygroundTests` covers the case these do not reach —
/// applying from `viewDidLayoutSubviews`, where the frame stays collapsed while the content still draws.
@MainActor
@Suite("Host sizing")
struct FLHostSizingTests {
    private func hosted() -> (UIView, FLHostView<FLText>) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let container = UIView(frame: window.bounds)
        let host = FLHostView<FLText>()

        host.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(container)
        container.addSubview(host)
        window.makeKeyAndVisible()

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        container.layoutIfNeeded()

        return (container, host)
    }

    @Test("applying schedules the layout pass that reads the new intrinsic size")
    func applyingSchedulesTheLayoutPass() {
        let (container, host) = hosted()
        let node = FLText("a line of text")
        let layout = node.layout(in: FLContext(width: 390))

        host.apply(node: node, layout: layout)
        container.layoutIfNeeded()

        #expect(host.frame.height == layout.size.height)
    }

    @Test("a re-apply that changes the size reaches the frame too")
    func reapplyingResizes() {
        let (container, host) = hosted()
        let short = FLText("one line")
        let long = FLText(String(repeating: "a longer body of text. ", count: 12))

        host.apply(node: short, layout: short.layout(in: FLContext(width: 390)))
        container.layoutIfNeeded()

        let grown = long.layout(in: FLContext(width: 390))

        host.apply(node: long, layout: grown)
        container.layoutIfNeeded()

        #expect(host.frame.height == grown.size.height)
    }
}
