import SwiftUI
import Testing
import UIKit

@testable import CellSystem

/// Measures FL against real SwiftUI: `UIHostingController.sizeThatFits(in:)` reports the size SwiftUI
/// resolves for a proposal, and it does not clamp to that proposal, so an overflowing subtree shows up
/// as a size larger than the box. Text metrics differ by a fraction of a point, hence the tolerance.
@MainActor
@Suite("SwiftUI parity")
struct FLSwiftUIParityTests {
    private let box: CGFloat = 160
    private let ratio: CGFloat = 16.0 / 9.0
    private var landscape: UIImage { FLImageSamples.landscape }
    private var portrait: UIImage { FLImageSamples.portrait }

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
        for sample in FlexiblePhotoSample.samples {
            let cap = FlexiblePhotoSample.maximumHeight
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
}
