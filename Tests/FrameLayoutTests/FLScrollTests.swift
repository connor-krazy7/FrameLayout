import Testing
import UIKit

@testable import FrameLayout

@MainActor
@Suite("Scroll sizing")
struct FLScrollTests {
    private func body(lines: Int) -> some FLNode {
        FLColor(.systemBlue).frame(width: 120, height: CGFloat(lines) * 40)
    }

    @Test("with nothing proposed along the axis, the region collapses to its content")
    func collapsesToContentWhenUnbounded() {
        let scroll = FLScroll { body(lines: 10) }
        let layout = scroll.layout(in: FLContext(width: 300))

        #expect(layout.contentSize.height == 400)
        #expect(layout.size.height == 400)
    }

    @Test("an offered extent becomes the viewport while the content keeps its own")
    func offeredExtentBecomesTheViewport() {
        let scroll = FLScroll { body(lines: 10) }
        let layout = scroll.layout(in: FLContext(width: 300, height: 150))

        #expect(layout.size.height == 150)
        #expect(layout.contentSize.height == 400)
    }

    @Test("frame(maxHeight:) makes a viewport, which needs the placement pass to work")
    func boundedFrameMakesAViewport() {
        let node = FLScroll { body(lines: 10) }.frame(maxHeight: 150)
        let layout = node.layout(in: FLContext(width: 300))

        #expect(layout.size.height == 150)
        #expect(layout.wrapped.contentSize.height == 400)
        #expect(layout.wrapped.size.height == 150)
    }

    @Test("the cross axis is proposed to the content exactly, and the region hugs what comes back")
    func crossAxisIsForwardedAndHugged() {
        let scroll = FLScroll {
            FLText("a line of text long enough to need wrapping inside the scrolling region")
        }
        let layout = scroll.layout(in: FLContext(width: 120))

        #expect(layout.contentSize.width <= 120)
        #expect(layout.size.width == layout.contentSize.width)
        #expect(layout.contentSize.height > 20)
    }

    @Test("a content that fills the cross axis makes the region fill it too")
    func crossAxisFillsWhenTheContentDoes() {
        let scroll = FLScroll { FLColor(.systemBlue).frame(height: 400) }
        let layout = scroll.layout(in: FLContext(width: 300))

        #expect(layout.size.width == 300)
    }

    @Test("a horizontal region leaves the width unbounded and takes the offered height")
    func horizontalAxisMirrorsTheVerticalOne() {
        let scroll = FLScroll(.horizontal) {
            FLHStack(spacing: 4) {
                FLForEach(Array(0..<8), id: \.self) { _ in
                    FLColor(.systemPink).frame(width: 60, height: 30)
                }
            }
        }
        let layout = scroll.layout(in: FLContext(width: 200, height: 30))

        #expect(layout.contentSize.width == CGFloat(8 * 60 + 7 * 4))
        #expect(layout.size.width == 200)
        #expect(layout.size.height == 30)
        #expect(layout.contentSize.height == 30)
    }

    @Test("a spacer inside a scroll collapses rather than filling forever")
    func spacersCollapse() {
        let scroll = FLScroll {
            FLVStack(spacing: 0) {
                FLColor(.systemBlue).frame(width: 40, height: 20)

                FLSpacer()

                FLColor(.systemBlue).frame(width: 40, height: 20)
            }
        }
        let layout = scroll.layout(in: FLContext(width: 300))

        #expect(layout.contentSize.height == 40)
        #expect(layout.size.height.isFinite)
    }

    @Test("configuration is layout-neutral but changes node identity")
    func configurationIsLayoutNeutral() {
        let plain = FLScroll { body(lines: 4) }
        let configured = FLScroll { body(lines: 4) }.scrollIndicators(.hidden).bounces(false)

        #expect(plain.layout(in: FLContext(width: 300)).size == configured.layout(in: FLContext(width: 300)).size)
        #expect(plain != configured)
    }
}
