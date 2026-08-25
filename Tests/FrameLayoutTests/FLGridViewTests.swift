import Testing
import UIKit

@testable import FrameLayout

private struct PhotoGrid: FLView {
    let count: Int

    var body: some FLNode {
        FLVGrid(columns: 3, spacing: 4) {
            FLForEach(Array(0..<count), id: \.self) { index in
                FLColor(.systemBlue)
                    .aspectRatio(1, contentMode: .fit)
                    .tag("cell-\(index)")
            }
        }
    }
}

@MainActor
@Suite("Grid rendering")
struct FLGridViewTests {
    private let context = FLContext(width: 320)
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))

    private func hosted(_ count: Int) -> FLHost<PhotoGrid> {
        let host = FLHost<PhotoGrid>()
        let node = PhotoGrid(count: count).node
        let layout = node.layout(in: context)

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("every cell is reachable by tag and sits at its computed frame")
    func cellsArePlaced() {
        let host = hosted(5)
        let first = host.registry.view(withTag: "cell-0")
        let fourth = host.registry.view(withTag: "cell-3")

        #expect(first?.bounds.size == CGSize(width: 104, height: 104))
        #expect(first.map { $0.convert(CGPoint.zero, to: host) } == CGPoint(x: 0, y: 0))
        #expect(fourth.map { $0.convert(CGPoint.zero, to: host) } == CGPoint(x: 0, y: 108))
    }

    @Test("adding items reuses the views already built")
    func viewsAreReusedAcrossApplies() {
        let host = hosted(5)
        let firstBefore = host.registry.view(withTag: "cell-0")
        let node = PhotoGrid(count: 7).node
        let layout = node.layout(in: context)

        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        #expect(host.registry.view(withTag: "cell-0") === firstBefore)
        #expect(host.registry.containsView(withTag: "cell-6"))
    }

    @Test("a grid inside a bounded scroll region scrolls its content")
    func gridInsideAScrollRegion() {
        struct ScrollingGrid: FLView {
            var body: some FLNode {
                FLScroll {
                    FLVGrid(columns: 3, spacing: 4) {
                        FLForEach(Array(0..<30), id: \.self) { _ in
                            FLColor(.systemBlue).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .tag("scroll")
            }
        }

        let host = FLHost<ScrollingGrid>()
        let node = ScrollingGrid().node
        let layout = node.layout(in: context)

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        let scroll = host.registry.view(withTag: "scroll", as: UIScrollView.self)

        #expect(layout.size.height == 200)
        #expect(scroll?.contentSize.height ?? 0 > 200)
    }
}
