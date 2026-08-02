import Testing
import UIKit

@testable import CellSystem

@MainActor
@Suite("Image comparison cases")
struct FLImageComparisonTests {
    private let box = FLImageSamples.boxWidth

    private func size(_ node: some FLNode) -> CGSize {
        node.layout(in: FLContext(width: box)).size
    }

    @Test("without resizable an image reports its own point size, whatever is offered")
    func intrinsicIgnoresTheProposal() {
        let landscape = FLImageSamples.landscape

        #expect(size(FLImage(landscape)) == landscape.size)
        #expect(FLImage(landscape).layout(in: FLContext(width: 40)).size == landscape.size)
    }

    @Test("resizable alone takes the proposal on the width and collapses the unproposed axis")
    func resizableTakesTheProposal() {
        let reserved = size(FLImage(FLImageSamples.landscape).resizable())

        #expect(reserved.width == box)
    }

    @Test("a fill overflows only when a height is actually supplied, not merely bounded")
    func fillOverflowsOnlyWithASuppliedHeight() {
        let ratio: CGFloat = 16.0 / 9.0
        let image = FLImage(FLImageSamples.landscape).resizable()
        let impliedHeight: CGFloat = box / ratio

        let fit = size(image.aspectRatio(ratio, contentMode: .fit))
        let bounded = size(image.aspectRatio(ratio, contentMode: .fill).frame(maxHeight: impliedHeight + 30))
        let supplied = size(image.aspectRatio(ratio, contentMode: .fill).frame(height: impliedHeight + 30))

        #expect(fit.width == box)
        #expect(bounded.width == box)
        #expect(bounded.height == impliedHeight)
        #expect(supplied.width > box)
        #expect(supplied.height == impliedHeight + 30)
    }

    private func renderedTint<Node: FLNode>(_ node: Node) -> UIColor? {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let host = FLHostView<Node>()
        let layout = node.layout(in: FLContext(width: box))

        window.addSubview(host)
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)

        return host.registry.imageView(withTag: "image")?.tintColor
    }

    private var symbol: FLImage {
        FLImage(UIImage(systemName: "photo.fill")).resizable()
    }

    @Test("foregroundColor tints an image that has no colour of its own")
    func foregroundColorTintsTheImage() {
        let node = symbol.frame(width: 44, height: 44).tag("image").foregroundColor(.systemPink)

        #expect(renderedTint(node) == .systemPink)
    }

    @Test("a colour reaching the image implies template rendering")
    func aColourImpliesTemplateRendering() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let node = symbol.frame(width: 44, height: 44).tag("image").foregroundColor(.systemPink)
        let host = FLHostView<FLEnvironmentOverride<FLTagged<FLFrame<FLImage>, String>>>()

        window.addSubview(host)
        host.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        host.apply(node: node, layout: node.layout(in: FLContext(width: box)))

        #expect(host.registry.imageView(withTag: "image")?.image?.renderingMode == .alwaysTemplate)
    }

    @Test("the colour nearest the image wins, collapsed onto the node or nested around it")
    func theNearestColourWins() {
        let collapsed = symbol
            .foregroundColor(.systemGreen)
            .foregroundColor(.systemPink)
            .frame(width: 44, height: 44)
            .tag("image")
        let nested = symbol
            .foregroundColor(.systemGreen)
            .frame(width: 44, height: 44)
            .tag("image")
            .foregroundColor(.systemPink)

        #expect(renderedTint(collapsed) == .systemGreen)
        #expect(renderedTint(nested) == .systemGreen)
    }

    @Test("landing the colour on the image costs a view less than landing it above")
    func onTheImageCostsNoWrapper() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let onImage = symbol.foregroundColor(.systemPink).frame(width: 44, height: 44).tag("image")
        let above = symbol.frame(width: 44, height: 44).tag("image").foregroundColor(.systemPink)

        let onImageHost = FLHostView<FLTagged<FLFrame<FLImage>, String>>()
        let aboveHost = FLHostView<FLEnvironmentOverride<FLTagged<FLFrame<FLImage>, String>>>()

        window.addSubview(onImageHost)
        window.addSubview(aboveHost)
        onImageHost.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        aboveHost.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        onImageHost.apply(node: onImage, layout: onImage.layout(in: FLContext(width: box)))
        aboveHost.apply(node: above, layout: above.layout(in: FLContext(width: box)))

        func viewCount(_ view: UIView) -> Int {
            1 + view.subviews.reduce(0) { $0 + viewCount($1) }
        }

        #expect(renderedTint(onImage) == renderedTint(above))
        #expect(viewCount(aboveHost) == viewCount(onImageHost) + 1)
    }

    @Test("tinting through the environment does not move anything")
    func inheritedTintIsLayoutNeutral() {
        let symbol = FLImage(UIImage(systemName: "photo.fill")).resizable().frame(width: 44, height: 44)

        #expect(size(symbol) == size(symbol.foregroundColor(.systemPink)))
    }

    @Test("a fixed frame plus clipping keeps a fill inside its box")
    func fixedFrameContainsAFill() {
        let reserved = size(
            FLImage(FLImageSamples.landscape)
                .resizable()
                .aspectRatio(16.0 / 9, contentMode: .fill)
                .frame(width: box, height: 60)
                .clipped()
        )

        #expect(reserved == CGSize(width: box, height: 60))
    }

    @Test("contentMode changes how the image fills its frame, never the frame")
    func contentModeIsLayoutNeutral() {
        let portrait = FLImage(FLImageSamples.portrait).resizable()
        let frame = CGSize(width: 80, height: 80)

        for mode in [UIView.ContentMode.scaleAspectFit, .scaleAspectFill, .scaleToFill] {
            #expect(size(portrait.contentMode(mode).frame(width: frame.width, height: frame.height)) == frame)
        }
    }

    @Test("a small image is blown up when resizable, and left alone when capped at its own width")
    func smallImageDependsOnTheCap() {
        let tiny = FLImage(FLImageSamples.tiny).resizable().aspectRatio(4.0 / 3, contentMode: .fit)

        #expect(size(tiny).width == box)
        #expect(size(tiny.frame(maxWidth: 40)).width == 40)
    }

    @Test("tinting does not move anything")
    func tintIsLayoutNeutral() {
        let symbol = FLImage(UIImage(systemName: "photo.fill")).resizable()
        let untinted = size(symbol.frame(width: 44, height: 44))
        let tinted = size(symbol.foregroundColor(.systemPink).frame(width: 44, height: 44))

        #expect(untinted == tinted)
    }
}
