import Testing
import UIKit

@testable import FrameLayout

private struct Gallery: FLView {
    let album: String
    let photos: Int
    let restored: CGPoint

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack(spacing: 4) {
                FLForEach(Array(0..<photos), id: \.self) { _ in
                    FLColor(.systemBlue).frame(width: 80, height: 60)
                }
            }
        }
        .initialContentOffset(restored, forContent: album)
        .tag("gallery")
    }
}

private struct Panel: FLView {
    let photos: Int

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack(spacing: 4) {
                FLForEach(Array(0..<photos), id: \.self) { _ in
                    FLColor(.systemPink).frame(width: 80, height: 60)
                }
            }
        }
        .initialContentOffset(CGPoint(x: 160, y: 0))
        .tag("panel")
    }
}

@MainActor
@Suite("Scroll initial offset")
struct FLScrollOffsetTests {
    private let context = FLContext(width: 200, height: 60)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 120))

    private func apply<Content: FLView>(_ content: Content, to host: FLHost<Content>) {
        let node = content.node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()
    }

    private func hosted<Content: FLView>(_ content: Content) -> FLHost<Content> {
        let host = FLHost<Content>()

        window.addSubview(host)
        window.makeKeyAndVisible()
        apply(content, to: host)

        return host
    }

    @Test("a gallery comes back where it was left, per album, across reuse")
    func perContentRestore() {
        var offsets: [String: CGPoint] = [:]
        let host = hosted(Gallery(album: "a", photos: 8, restored: .zero))

        func scroll() -> UIScrollView? {
            host.registry.view(withTag: "gallery", as: UIScrollView.self)
        }

        scroll()?.contentOffset = CGPoint(x: 120, y: 0)
        offsets["a"] = CGPoint(x: 120, y: 0)

        apply(Gallery(album: "b", photos: 8, restored: offsets["b"].or(.zero)), to: host)

        #expect(scroll()?.contentOffset.x == 0)

        apply(Gallery(album: "a", photos: 8, restored: offsets["a"].or(.zero)), to: host)

        #expect(scroll()?.contentOffset.x == 120)
    }

    @Test("within one content it is applied once, so dragging is not undone by a data change")
    func appliedOncePerContent() {
        let host = hosted(Gallery(album: "a", photos: 8, restored: CGPoint(x: 40, y: 0)))

        func scroll() -> UIScrollView? {
            host.registry.view(withTag: "gallery", as: UIScrollView.self)
        }

        #expect(scroll()?.contentOffset.x == 40)

        scroll()?.contentOffset = CGPoint(x: 200, y: 0)
        apply(Gallery(album: "a", photos: 9, restored: CGPoint(x: 40, y: 0)), to: host)

        #expect(scroll()?.contentOffset.x == 200)
    }

    @Test("without a content token it is applied once for the view and never again")
    func appliedOncePerView() {
        let host = hosted(Panel(photos: 8))

        func scroll() -> UIScrollView? {
            host.registry.view(withTag: "panel", as: UIScrollView.self)
        }

        #expect(scroll()?.contentOffset.x == 160)

        scroll()?.contentOffset = .zero
        apply(Panel(photos: 12), to: host)

        #expect(scroll()?.contentOffset.x == 0)
    }

    @Test("the offset lands after contentSize, so it is not clamped away")
    func offsetIsNotClampedByAnEmptyContent() {
        let host = hosted(Gallery(album: "a", photos: 8, restored: CGPoint(x: 300, y: 0)))
        let scroll = host.registry.view(withTag: "gallery", as: UIScrollView.self)

        #expect(scroll?.contentSize.width == CGFloat(8 * 80 + 7 * 4))
        #expect(scroll?.contentOffset.x == 300)
    }
}
