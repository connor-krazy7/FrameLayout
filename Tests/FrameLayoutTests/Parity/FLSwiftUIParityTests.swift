import SwiftUI
import Testing
import UIKit

@testable import FrameLayout

/// Measures FL against real SwiftUI: `UIHostingController.sizeThatFits(in:)` reports the size SwiftUI
/// resolves for a proposal, and it does not clamp to that proposal, so an overflowing subtree shows up
/// as a size larger than the box. Text metrics differ by a fraction of a point, hence the tolerance.
@MainActor
@Suite("SwiftUI parity")
struct FLSwiftUIParityTests {
    private let box: CGFloat = 160
    private let ratio: CGFloat = 16.0 / 9.0
    private var landscape: UIImage { FixtureSwatch.landscape }
    private var portrait: UIImage { FixtureSwatch.portrait }

    private func swiftUISize(_ view: some View, proposedHeight: CGFloat = .infinity) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: box, height: proposedHeight))
    }

    private func expectSame(
        _ fl: CGSize,
        _ swiftUI: CGSize,
        tolerance: CGFloat = 0.5,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(fl.width - swiftUI.width) <= tolerance, "width", sourceLocation: sourceLocation)
        #expect(abs(fl.height - swiftUI.height) <= tolerance, "height", sourceLocation: sourceLocation)
    }

    private var absentNode: FLOptional<FLFrame<FLColor>> { optionalNode(false) }
    private var presentNode: FLOptional<FLFrame<FLColor>> { optionalNode(true) }
    private var absentView: some View { optionalView(false) }
    private var presentView: some View { optionalView(true) }

    @FLNodeBuilder private func optionalNode(_ isVisible: Bool) -> FLOptional<FLFrame<FLColor>> {
        if isVisible {
            FLColor(.systemRed).frame(width: 40, height: 40)
        }
    }

    @ViewBuilder private func optionalView(_ isVisible: Bool) -> some View {
        if isVisible {
            Color.red.frame(width: 40, height: 40)
        }
    }

    /// The sample between two 40pt swatches, so a child that is dropped reads as 88 and one that is kept
    /// at zero size reads as 96.
    private func stacked(_ node: some FLNode, spacing: CGFloat) -> CGFloat {
        FLVStack(spacing: spacing) {
            FLColor(.systemTeal).frame(width: 40, height: 40)
            node
            FLColor(.systemIndigo).frame(width: 40, height: 40)
        }
        .layout(in: FLContext(width: box)).size.height
    }

    private func stacked(_ view: some View, spacing: CGFloat) -> CGFloat {
        UIHostingController(
            rootView: VStack(spacing: spacing) {
                Color.teal.frame(width: 40, height: 40)
                view
                Color.indigo.frame(width: 40, height: 40)
            }
        )
        .sizeThatFits(in: CGSize(width: box, height: CGFloat.infinity)).height
    }

    @Test("an image reports its own point size until it is made resizable")
    func intrinsicMatches() {
        expectSame(
            FLImage(landscape).layout(in: FLContext(width: box)).size,
            swiftUISize(Image(uiImage: landscape))
        )
    }

    @Test("fit and fill agree when no height is proposed and no frame bounds them")
    func unframedRatiosMatch() {
        expectSame(
            FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fit)
                .layout(in: FLContext(width: box)).size,
            swiftUISize(Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fit))
        )
        expectSame(
            FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill)
                .layout(in: FLContext(width: box)).size,
            swiftUISize(Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill))
        )
    }

    @Test("an exact height makes a fill overflow, and the overflow grows the parent in both systems")
    func exactHeightOverflowsAndPropagates() {
        let fl = FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(height: 140)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(height: 140)
        )

        expectSame(fl, swiftUI)
        #expect(fl.width > box)
        #expect(swiftUI.width > box)
    }

    @Test("maxHeight clamps the answer instead of supplying a height, so a fill stays in the box")
    func maxHeightDoesNotSupplyAHeight() {
        let fl = FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(maxHeight: 140)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(maxHeight: 140)
        )

        expectSame(fl, swiftUI)
        #expect(fl.width == box)
    }

    @Test("maxHeight does clamp a proposed height, and then the fill overflows again")
    func maxHeightClampsAProposedHeight() {
        let fl = FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(maxHeight: 140)
            .layout(in: FLContext(width: box, height: 1000)).size
        let swiftUI = swiftUISize(
            Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(maxHeight: 140),
            proposedHeight: 1000
        )

        expectSame(fl, swiftUI)
        #expect(fl.width > box)
    }

    @Test("a flexible child is not inflated to maxHeight when nothing proposed a height")
    func maxHeightDoesNotInflateAFlexibleChild() {
        let fl = FLColor(.systemRed).frame(maxHeight: 140).layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(Color.red.frame(maxHeight: 140))

        #expect(fl.height < 140)
        #expect(swiftUI.height < 140)
        #expect(fl.width == swiftUI.width)
    }

    @Test("maxWidth infinity still takes the whole proposed width")
    func infiniteMaxWidthFillsTheProposal() {
        let fl = FLColor(.systemRed).frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(Color.red.frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20))

        expectSame(fl, swiftUI)
        #expect(fl.width == box)
    }

    @Test("a fixed frame ignores the proposal and reports its own size")
    func fixedFrameIgnoresTheProposal() {
        expectSame(
            FLColor(.systemRed).frame(width: 300, height: 100).layout(in: FLContext(width: box)).size,
            swiftUISize(Color.red.frame(width: 300, height: 100))
        )
    }

    @Test("a fixed frame still sizes the image inside it rather than letting it keep its own size")
    func fixedFrameSizesTheImage() {
        expectSame(
            FLImage(landscape).resizable().frame(width: 44, height: 44).layout(in: FLContext(width: box)).size,
            swiftUISize(Image(uiImage: landscape).resizable().frame(width: 44, height: 44))
        )
    }

    @Test("an overflowing child grows the stack around it")
    func overflowGrowsTheStack() {
        let fl = FLVStack(spacing: 0) {
            FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(height: 140)
            FLText("hi").font(.systemFont(ofSize: 12))
        }
        .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            VStack(spacing: 0) {
                Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(height: 140)
                Text("hi").font(.system(size: 12))
            }
        )

        expectSame(fl, swiftUI, tolerance: 1)
        #expect(fl.width > box)
    }

    @Test("capping a tall photo with maxHeight reserves the cap but leaves the content overflowing")
    func tallPhotoCappedByHeight() {
        let tallRatio = portrait.size.width / portrait.size.height
        let fl = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(maxHeight: 100)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(maxHeight: 100)
        )

        let fittedWidth = 100 * tallRatio

        expectSame(fl, swiftUI)
        #expect(fl.height == 100)
        #expect(fl.width == box)
        #expect(swiftUI.width == box)
        #expect(fittedWidth < box)
    }

    @Test("expressing the cap on the width fits the photo, in both systems")
    func aWidthCapActuallyFits() {
        let tallRatio = portrait.size.width / portrait.size.height
        let cap: CGFloat = 100
        let fl = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit)
            .frame(maxWidth: cap * tallRatio)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(tallRatio, contentMode: .fit)
                .frame(maxWidth: cap * tallRatio)
        )

        expectSame(fl, swiftUI)
        #expect(fl.height <= cap)
        #expect(fl.width < box)
    }

    @Test("an exact height fits a tall photo too, and spends exactly that height")
    func anExactHeightFits() {
        let tallRatio = portrait.size.width / portrait.size.height
        let cap: CGFloat = 100
        let fl = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(height: cap)
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(height: cap)
        )

        expectSame(fl, swiftUI)
        #expect(fl.height == cap)
    }

    @Test("the boundedBy overload matches the maxHeight-times-ratio spelling it replaces")
    func maxHeightOverloadMatchesTheArithmetic() {
        for pixelSize in FixtureSwatch.photoSizes {
            let cap: CGFloat = 140
            let sample = (
                image: FixtureSwatch.image(size: pixelSize, color: .systemIndigo),
                ratio: pixelSize.width / pixelSize.height,
                pixelSize: pixelSize
            )
            let fl = FLImage(sample.image)
                .resizable()
                .aspectRatio(
                    sample.ratio,
                    contentMode: .fit,
                    boundedBy: CGSize(width: sample.pixelSize.width, height: cap)
                )
                .layout(in: FLContext(width: box))
                .size
            let swiftUI = swiftUISize(
                Image(uiImage: sample.image)
                    .resizable()
                    .aspectRatio(sample.ratio, contentMode: .fit)
                    .frame(maxWidth: min(sample.pixelSize.width, cap * sample.ratio))
            )

            expectSame(fl, swiftUI, tolerance: 1)
            #expect(fl.height <= cap + 1)
            #expect(fl.width <= box)
        }
    }

    @Test("the maxHeight overload caps the height the plain modifier could not")
    func maxHeightOverloadCapsTheHeight() {
        let tallRatio = portrait.size.width / portrait.size.height
        let cap: CGFloat = 100
        let plain = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit)
            .frame(maxHeight: cap)
            .layout(in: FLContext(width: box)).size
        let capped = FLImage(portrait).resizable()
            .aspectRatio(tallRatio, contentMode: .fit, maxHeight: cap)
            .layout(in: FLContext(width: box)).size

        #expect(plain.width == box)
        #expect(capped.height <= cap)
        #expect(abs(capped.width / capped.height - tallRatio) < 0.02)
    }

    @Test("a tall photo fits rather than spills once a height is proposed, in both systems")
    func tallPhotoFitsUnderAProposedHeight() {
        let tallRatio = portrait.size.width / portrait.size.height
        let cap: CGFloat = 100
        let fl = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(maxHeight: cap)
            .layout(in: FLContext(width: box, height: 800)).size
        let swiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(maxHeight: cap),
            proposedHeight: 800
        )

        expectSame(fl, swiftUI)
        #expect(fl.height == cap)
        #expect(fl.width < box)
    }

    @Test("fixedSize pins SwiftUI to the unspecified-height regime FL measures in")
    func fixedSizeMatchesTheUnspecifiedRegime() {
        let tallRatio = portrait.size.width / portrait.size.height
        let cap: CGFloat = 100
        let chain = Image(uiImage: portrait).resizable()
            .aspectRatio(tallRatio, contentMode: .fit)
            .frame(maxHeight: cap)
        let fl = FLImage(portrait).resizable().aspectRatio(tallRatio, contentMode: .fit).frame(maxHeight: cap)
            .layout(in: FLContext(width: box)).size

        let pinned = swiftUISize(chain.fixedSize(horizontal: false, vertical: true), proposedHeight: 200)
        let unpinned = swiftUISize(chain, proposedHeight: 200)

        expectSame(pinned, fl)
        #expect(unpinned != pinned)
        #expect(unpinned.width < box)
    }

    /// Outer sizes agreed for a long time while the rendering did not, because `sizeThatFits` says nothing
    /// about where the child landed. This renders the SwiftUI chain and finds the photo's drawn extent, so
    /// child geometry is compared rather than inferred.
    private func drawnBounds(of view: some View, canvasWidth: CGFloat) -> CGRect? {
        let renderer = ImageRenderer(content: view.frame(width: canvasWidth))

        renderer.scale = 1

        guard let rendered = renderer.cgImage else { return nil }

        let width = rendered.width
        let height = rendered.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = pixels.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }

        context?.draw(rendered, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let isRed = pixels[offset] > 128 && pixels[offset + 1] < 100 && pixels[offset + 3] > 128

                guard isRed else { continue }

                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= 0 else { return nil }

        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func solidRed(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    @Test("a bounded frame hands its resolved box to the child, in both systems")
    func childGeometryMatches() {
        let image = solidRed(size: CGSize(width: 60, height: 120))
        let chain = Image(uiImage: image)
            .resizable()
            .aspectRatio(0.5, contentMode: .fit)
            .frame(maxHeight: 100)
            .fixedSize(horizontal: false, vertical: true)
        let fl = FLImage(image).resizable().aspectRatio(0.5, contentMode: .fit).frame(maxHeight: 100)
            .layout(in: FLContext(width: box))
        let drawn = drawnBounds(of: chain, canvasWidth: box)

        #expect(fl.size == CGSize(width: box, height: 100))
        #expect(fl.wrappedFrame.size == CGSize(width: 50, height: 100))
        #expect(drawn?.width == 50)
        #expect(drawn?.height == 100)
        #expect(abs((drawn?.midX).or(0) - box / 2) <= 1)
        #expect(abs(fl.wrappedFrame.midX - box / 2) <= 1)
    }

    @Test("a fill still overflows the box it is given, in both systems")
    func fillStillOverflows() {
        let image = solidRed(size: CGSize(width: 60, height: 120))
        let chain = Image(uiImage: image)
            .resizable()
            .aspectRatio(0.5, contentMode: .fill)
            .frame(height: 100)
            .fixedSize(horizontal: false, vertical: true)
        let fl = FLImage(image).resizable().aspectRatio(0.5, contentMode: .fill).frame(height: 100)
            .layout(in: FLContext(width: box))

        #expect(fl.size.height == 100)
        #expect(fl.wrappedFrame.height > 100)
        #expect(swiftUISize(chain).height == 100)
    }

    @Test("the cap overloads bound the reserved box for fill as well as fit")
    func capOverloadsBoundBothContentModes() {
        let cap: CGFloat = 100
        let fit = FLImage(portrait).resizable()
            .aspectRatio(0.5, contentMode: .fit, maxHeight: cap)
            .layout(in: FLContext(width: box, height: 300)).size
        let fill = FLImage(portrait).resizable()
            .aspectRatio(0.5, contentMode: .fill, maxHeight: cap)
            .layout(in: FLContext(width: box, height: 300)).size

        #expect(fit.height <= cap)
        #expect(fill.height <= cap)
    }

    @Test("the bare frame spelling stays SwiftUI-shaped for both content modes")
    func bareWidthCapMatchesSwiftUI() {
        let cap: CGFloat = 50
        let fitFL = FLImage(portrait).resizable().aspectRatio(0.5, contentMode: .fit).frame(maxWidth: cap)
            .layout(in: FLContext(width: box, height: 300)).size
        let fitSwiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(0.5, contentMode: .fit).frame(maxWidth: cap),
            proposedHeight: 300
        )
        let fillFL = FLImage(portrait).resizable().aspectRatio(0.5, contentMode: .fill).frame(maxWidth: cap)
            .layout(in: FLContext(width: box, height: 300)).size
        let fillSwiftUI = swiftUISize(
            Image(uiImage: portrait).resizable().aspectRatio(0.5, contentMode: .fill).frame(maxWidth: cap),
            proposedHeight: 300
        )

        expectSame(fitFL, fitSwiftUI)
        expectSame(fillFL, fillSwiftUI)
        #expect(fillFL.height == 300)
    }

    @Test("every cap overload reserves a ratio-shaped box, whichever limit was given")
    func capOverloadsReserveARatioShapedBox() {
        let ratio: CGFloat = 0.5
        let cap: CGFloat = 50
        let context = FLContext(width: box, height: 300)

        for mode in [FLAspectContentMode.fit, .fill] {
            let fromWidth = FLImage(portrait).resizable()
                .aspectRatio(ratio, contentMode: mode, maxWidth: cap)
                .layout(in: context).size
            let fromHeight = FLImage(portrait).resizable()
                .aspectRatio(ratio, contentMode: mode, maxHeight: cap / ratio)
                .layout(in: context).size
            let fromBox = FLImage(portrait).resizable()
                .aspectRatio(ratio, contentMode: mode, boundedBy: CGSize(width: cap, height: 900))
                .layout(in: context).size

            #expect(abs(fromWidth.width / fromWidth.height - ratio) < 0.02)
            #expect(fromWidth == fromHeight)
            #expect(fromWidth == fromBox)
            #expect(fromWidth.width <= cap)
        }
    }

    @Test("both spellings fit the photo, but only the cap overload makes the reserved box hug it")
    func hugVersusFullWidthBox() {
        let ratio: CGFloat = 0.5625
        let cap: CGFloat = 220
        let offered: CGFloat = 300
        let hugging = FLImage(portrait).resizable()
            .aspectRatio(ratio, contentMode: .fit, maxHeight: cap)
            .layout(in: FLContext(width: offered))
        let fullWidth = FLImage(portrait).resizable()
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxHeight: cap)
            .layout(in: FLContext(width: offered))

        #expect(hugging.size.height == cap)
        #expect(fullWidth.size.height == cap)
        #expect(abs(hugging.size.width - cap * ratio) <= 1)
        #expect(fullWidth.size.width == offered)
        #expect(abs(fullWidth.wrappedFrame.width - cap * ratio) <= 1)
    }

    @Test("an unbounded axis follows the child rather than filling the proposal")
    func unboundedAxisFollowsTheChild() {
        let text = FLText("hi").font(.systemFont(ofSize: 12)).frame(maxHeight: 100)
            .layout(in: FLContext(width: box)).size
        let textSwiftUI = swiftUISize(Text("hi").font(.system(size: 12)).frame(maxHeight: 100))
        let image = FLImage(portrait).frame(maxHeight: 100).layout(in: FLContext(width: box)).size
        let imageSwiftUI = swiftUISize(Image(uiImage: portrait).frame(maxHeight: 100))

        expectSame(text, textSwiftUI, tolerance: 1)
        expectSame(image, imageSwiftUI)
        #expect(text.width < 20)
        #expect(image.width == portrait.size.width)
    }

    @Test("a bounded axis follows the clamped proposal, which is what maxWidth infinity relies on")
    func boundedAxisFollowsTheProposal() {
        let filled = FLText("hi").font(.systemFont(ofSize: 12)).frame(maxWidth: .infinity)
            .layout(in: FLContext(width: box)).size
        let filledSwiftUI = swiftUISize(Text("hi").font(.system(size: 12)).frame(maxWidth: .infinity))
        let capped = FLText("hi").font(.systemFont(ofSize: 12)).frame(maxHeight: 100)
            .layout(in: FLContext(width: box, height: 400)).size
        let cappedSwiftUI = UIHostingController(
            rootView: Text("hi").font(.system(size: 12)).frame(maxHeight: 100)
        )
        .sizeThatFits(in: CGSize(width: box, height: 400))

        expectSame(filled, filledSwiftUI, tolerance: 1)
        expectSame(capped, cappedSwiftUI, tolerance: 1)
        #expect(filled.width == box)
        #expect(capped.height == 100)
    }

    /// `min(W, H·r)` and `min(H, W/r)` look like two independent choices, but `W ≤ H·r` and `W/r ≤ H` are the
    /// same inequality, so both pick from the same binding dimension and the derived pair is always exactly
    /// ratio-shaped. What the reserved box does with that pair still depends on the proposal.
    @Test("the derived limits never split, so the reserved box keeps the ratio when nothing tighter is proposed")
    func derivedLimitsNeverSplit() {
        let ratios: [CGFloat] = [0.25, 0.5625, 1, 1.5, 4]
        let limits = [
            CGSize(width: 60, height: 900),
            CGSize(width: 900, height: 60),
            CGSize(width: 120, height: 120),
            CGSize(width: CGFloat.infinity, height: 140),
            CGSize(width: 260, height: CGFloat.infinity),
        ]

        for ratio in ratios {
            for limit in limits {
                let size = FLColor(.systemRed)
                    .aspectRatio(ratio, contentMode: .fit, boundedBy: limit)
                    .layout(in: FLContext(width: 320))
                    .size
                let tolerance = ratio * 0.03 + 0.05

                #expect(size.width <= limit.width + 1)
                #expect(size.height <= limit.height + 1)
                #expect(size.height > 0)
                #expect(abs(size.width / size.height - ratio) < tolerance)
            }
        }
    }

    @Test("a proposal tighter than the limits shapes the box, and the child stays ratio-shaped inside it")
    func aTighterProposalShapesTheBox() {
        let ratio: CGFloat = 0.25
        let layout = FLColor(.systemRed)
            .aspectRatio(ratio, contentMode: .fit, boundedBy: CGSize(width: 260, height: CGFloat.infinity))
            .layout(in: FLContext(width: 320, height: 480))

        #expect(layout.size == CGSize(width: 260, height: 480))
        #expect(abs(layout.wrappedFrame.width / layout.wrappedFrame.height - ratio) < 0.05)
        #expect(layout.wrappedFrame.width < layout.size.width)
    }

    @Test("a scroll region collapses to its content when no extent is offered, in both systems")
    func scrollCollapsesWithoutAnOfferedExtent() {
        let fl = FLScroll { FLColor(.systemBlue).frame(width: 100, height: 400) }
            .layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(
            ScrollView { Color.blue.frame(width: 100, height: 400) }
                .fixedSize(horizontal: false, vertical: true)
        )

        expectSame(fl, swiftUI)
        #expect(fl.height == 400)
    }

    @Test("an offered extent becomes the viewport, in both systems")
    func scrollTakesTheOfferedExtent() {
        let fl = FLScroll { FLColor(.systemBlue).frame(width: 100, height: 400) }
            .layout(in: FLContext(width: box, height: 150)).size
        let swiftUI = swiftUISize(
            ScrollView { Color.blue.frame(width: 100, height: 400) },
            proposedHeight: 150
        )

        expectSame(fl, swiftUI)
        #expect(fl.height == 150)
    }

    // Both resolve per run, so the modifier reaches only the text that carries no font of its own. The
    // second pair of assertions is the load-bearing one: equality alone would still pass if both systems
    // started letting the modifier win.
    @Test("a font on the attributed string beats .font(_:), in both systems")
    func attributedFontBeatsTheModifier() {
        let body = "a line of text long enough to wrap at this width"
        let attributed = NSAttributedString(string: body, attributes: [.font: UIFont.systemFont(ofSize: 30)])

        var swiftUIAttributed = AttributedString(body)
        swiftUIAttributed.font = .system(size: 30)

        let fl = FLText(attributed).font(.systemFont(ofSize: 10)).layout(in: FLContext(width: box)).size
        let swiftUI = swiftUISize(Text(swiftUIAttributed).font(.system(size: 10)))

        expectSame(fl, swiftUI, tolerance: 1)

        let atThirty = FLText(NSAttributedString(string: body)).font(.systemFont(ofSize: 30))
            .layout(in: FLContext(width: box)).size
        let atTen = FLText(NSAttributedString(string: body)).font(.systemFont(ofSize: 10))
            .layout(in: FLContext(width: box)).size

        #expect(fl == atThirty, "the string's 30pt font is what was used")
        #expect(fl != atTen, "the modifier's 10pt font was not")
    }

    @Test("a font resolves per run, so a modifier reaches only the bare part")
    func fontResolvesPerRun() {
        let body = "a line of text long enough to wrap at this width"
        let half = NSRange(location: 0, length: body.count / 2)
        let partly = NSMutableAttributedString(string: body)
        partly.addAttribute(.font, value: UIFont.systemFont(ofSize: 30), range: half)

        var swiftUIPartly = AttributedString(body)
        let upper = swiftUIPartly.index(swiftUIPartly.startIndex, offsetByCharacters: body.count / 2)
        swiftUIPartly[swiftUIPartly.startIndex..<upper].font = .system(size: 30)

        let fl = FLText(partly).font(.systemFont(ofSize: 10)).layout(in: FLContext(width: box)).size

        expectSame(fl, swiftUISize(Text(swiftUIPartly).font(.system(size: 10))), tolerance: 1)

        let allThirty = FLText(NSAttributedString(string: body)).font(.systemFont(ofSize: 30))
            .layout(in: FLContext(width: box)).size
        let allTen = FLText(NSAttributedString(string: body)).font(.systemFont(ofSize: 10))
            .layout(in: FLContext(width: box)).size

        #expect(fl.height > allTen.height, "the 30pt run is taller than an all-10pt line")
        #expect(fl.height < allThirty.height, "and shorter than an all-30pt one")
    }

    @Test("the font nearest the text wins, and text beats the environment")
    func nearestFontWins() {
        let body = "a line of text long enough to wrap at this width"
        let plain = NSAttributedString(string: body)

        let flChained = FLText(plain).font(.systemFont(ofSize: 30)).font(.systemFont(ofSize: 10))
            .layout(in: FLContext(width: box)).size

        expectSame(
            flChained,
            swiftUISize(Text(body).font(.system(size: 30)).font(.system(size: 10))),
            tolerance: 1
        )

        let flInherited = FLText(plain).font(.systemFont(ofSize: 10))
            .environment(FLEnvironmentOverrides(font: .systemFont(ofSize: 30)))
            .layout(in: FLContext(width: box)).size

        expectSame(
            flInherited,
            swiftUISize(Text(body).font(.system(size: 10)).environment(\.font, .system(size: 30))),
            tolerance: 1
        )

        #expect(flChained != flInherited, "the two precedence rules resolve to different fonts")
    }

    @Test("padding shrinks the proposal the child sees, in both systems")
    func paddingShrinksTheProposal() {
        expectSame(
            FLImage(landscape).resizable().aspectRatio(ratio, contentMode: .fill).frame(maxHeight: 140).padding(8)
                .layout(in: FLContext(width: box)).size,
            swiftUISize(
                Image(uiImage: landscape).resizable().aspectRatio(ratio, contentMode: .fill)
                    .frame(maxHeight: 140).padding(8)
            )
        )
    }

    // MARK: - An absent optional

    /// Measured in a container rather than with `swiftUISize`, because the question is whether the child
    /// is given a **slot**, which a root measurement cannot see. Do not drop the spacing argument: at
    /// spacing 0 every assertion here passes with the elision broken.
    @Test("an absent optional contributes no slot, and neither does anything wrapped around it")
    func absentContributesNoSlot() {
        #expect(stacked(absentNode, spacing: 8) == stacked(absentView, spacing: 8))
        #expect(stacked(absentNode.padding(10), spacing: 8) == stacked(absentView.padding(10), spacing: 8))
        #expect(
            stacked(absentNode.frame(width: 100, height: 100), spacing: 8)
                == stacked(absentView.frame(width: 100, height: 100), spacing: 8)
        )
        #expect(
            stacked(absentNode.frame(maxHeight: 100), spacing: 8)
                == stacked(absentView.frame(maxHeight: 100), spacing: 8)
        )
        #expect(
            stacked(absentNode.padding(10).background(.systemGreen), spacing: 8)
                == stacked(absentView.padding(10).background(Color.green), spacing: 8)
        )
        #expect(stacked(absentNode.padding(10), spacing: 8) == 88, "the two swatches and one gap")
    }

    /// The boundary of the rule above: a wrapper is transparent to its child being absent, a view that is
    /// a thing of its own is not.
    @Test("a scroll view and a button keep their slot when their content is absent")
    func aViewOfItsOwnKeepsItsSlot() {
        let flScroll = FLScroll { absentNode }
        let flButton = FLButton(tag: "probe") { absentNode }

        #expect(stacked(flScroll, spacing: 8) == stacked(ScrollView { absentView }, spacing: 8))
        #expect(stacked(flButton, spacing: 8) == stacked(Button(action: {}) { absentView }, spacing: 8))
        #expect(stacked(flButton, spacing: 8) == 96)
        #expect(flScroll.isAbsent == false)
        #expect(flButton.isAbsent == false)
    }

    /// Why the row above can only be measured in a container: at the root both systems resolve the
    /// modifiers around the absent child and report 20x20, while a container gives it nothing.
    /// `sizeThatFits` reports the first and says nothing about the second.
    @Test("at the root, both systems still resolve a modifier over an absent optional")
    func absentAtTheRootIsNotTheContainer() {
        expectSame(absentNode.padding(10).layout(in: FLContext(width: box)).size, swiftUISize(absentView.padding(10)))

        #expect(absentNode.padding(10).layout(in: FLContext(width: box)).size == CGSize(width: 20, height: 20))
        #expect(stacked(absentNode.padding(10), spacing: 8) == 88)
    }

    @Test("a present optional is unaffected, slot and spacing included")
    func presentKeepsItsSlot() {
        #expect(stacked(presentNode, spacing: 8) == stacked(presentView, spacing: 8))
        #expect(stacked(presentNode, spacing: 8) == 136)
    }

    /// A box that survives an absent child is a **drawn** box, in both systems: a decoration sits above
    /// the optional and fills its own bounds. Asserted in pixels because no size assertion can see it —
    /// suppressing the fill leaves every number in this suite unchanged.
    ///
    /// Both rows carry a present control. A rendering probe that returns zero because it is wired wrong
    /// looks exactly like one reporting that nothing was drawn, and did, twice, while this was written.
    @Test("a surviving box is painted, and both systems paint it")
    func aSurvivingBoxIsPainted() {
        let flPresent = FLColor(.systemRed).frame(width: 40, height: 40).padding(10).background(.systemGreen)
        let flAbsent = absentNode.padding(10).background(.systemGreen)

        #expect(paintedPixels(of: presentView.padding(10).background(Color.green)) == 60 * 60)
        #expect(paintedPixels(of: absentView.padding(10).background(Color.green)) == 20 * 20)
        #expect(paintedPixels(of: flPresent) == 60 * 60)
        #expect(paintedPixels(of: flAbsent) == 20 * 20)
    }

    private func paintedPixels(of view: some View) -> Int {
        let renderer = ImageRenderer(content: view)

        renderer.scale = 1

        return renderer.cgImage.map(opaquePixels(of:)).or(-1)
    }

    /// Rendered through a window at scale 1, since a detached layer draws nothing and the default format
    /// would count the screen's scale squared.
    private func paintedPixels<Node: FLNode>(of node: Node) -> Int {
        let layout = node.layout(in: FLContext(width: box))
        let host = FLHostView<Node>()
        let window = UIWindow(frame: CGRect(origin: .zero, size: layout.size))
        let format = UIGraphicsImageRendererFormat.default()

        format.scale = 1
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        window.addSubview(host)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(size: layout.size, format: format).image { context in
            host.layer.render(in: context.cgContext)
        }

        return image.cgImage.map(opaquePixels(of:)).or(-1)
    }

    private func opaquePixels(of image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = pixels.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }

        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return stride(from: 3, to: pixels.count, by: 4).reduce(into: 0) { count, index in
            if pixels[index] > 0 {
                count += 1
            }
        }
    }

}
