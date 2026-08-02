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

    @Test("the maxHeight overload matches the maxHeight-times-ratio spelling it replaces")
    func maxHeightOverloadMatchesTheArithmetic() {
        for sample in FlexiblePhotoSample.samples {
            let cap = FlexiblePhotoSample.maximumHeight
            let fl = FLImage(sample.image)
                .resizable()
                .aspectRatio(sample.ratio, contentMode: .fit, maxWidth: sample.pixelSize.width, maxHeight: cap)
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
