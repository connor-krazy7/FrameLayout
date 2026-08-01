import Testing
import UIKit
@testable import CellSystem

@Suite("Image and aspect ratio")
struct FLImageTests {
    private func swatch(_ size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private var wide: UIImage { swatch(CGSize(width: 40, height: 20)) }

    @Test("an image reports its own size and ignores the proposal")
    func intrinsicIgnoresProposal() {
        let node = FLImage(wide)

        #expect(node.layout(in: FLContext(width: 300)).size == CGSize(width: 40, height: 20))
        #expect(node.layout(in: FLContext(width: 10)).size == CGSize(width: 40, height: 20))
        #expect(node.layout(in: FLContext.unspecified).size == CGSize(width: 40, height: 20))
    }

    @Test("resizable takes the proposal on both axes")
    func resizableAcceptsProposal() {
        let node = FLImage(wide).resizable()

        #expect(node.layout(in: FLContext(width: 200, height: 80)).size == CGSize(width: 200, height: 80))
        // with nothing proposed, the ideal is still the image itself
        #expect(node.layout(in: FLContext.unspecified).size == CGSize(width: 40, height: 20))
        #expect(node.layout(in: FLContext(width: .minimum, height: .minimum)).size == .zero)
        #expect(node.layout(in: FLContext(width: .maximum)).size.width == .infinity)
    }

    @Test("resizable plus aspectRatio fit reproduces the old fit mode")
    func fitViaModifier() {
        let node = FLImage(wide).resizable().aspectRatio(contentMode: .fit)

        // width is tighter: 300/40 = 7.5 vs 300/20 = 15
        #expect(node.layout(in: FLContext(width: 300, height: 300)).size == CGSize(width: 300, height: 150))
        // now height is tighter
        #expect(node.layout(in: FLContext(width: 100, height: 20)).size == CGSize(width: 40, height: 20))
        #expect(node.layout(in: FLContext(width: 300, height: 40)).size == CGSize(width: 80, height: 40))
    }

    @Test("aspectRatio fill covers the proposal instead of fitting inside it")
    func fillContentMode() {
        let node = FLImage(wide).resizable().aspectRatio(contentMode: .fill)

        #expect(node.layout(in: FLContext(width: 300, height: 300)).size == CGSize(width: 600, height: 300))
    }

    @Test("an explicit ratio needs no image, which is how space is reserved")
    func explicitRatioReservesSpace() {
        let placeholder = FLColor(.clear).aspectRatio(16 / 9)

        #expect(placeholder.layout(in: FLContext(width: 320)).size == CGSize(width: 320, height: 180))
    }

    @Test("a derived ratio needs an ideal size, so an empty child collapses")
    func derivedRatioNeedsContent() {
        #expect(FLImage(nil).resizable().aspectRatio().layout(in: FLContext(width: 300, height: 300)).size == .zero)
    }

    @Test("no upscaling is a max frame rather than its own mode")
    func fitDownViaFrame() {
        let node = FLImage(wide)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 40)

        #expect(node.layout(in: FLContext(width: 300, height: 300)).size.width == 40)
    }

    @Test("aspectRatio(1) plus a capsule is an honest circle")
    func circleFromAspectRatio() {
        let node = FLColor(.systemBlue).aspectRatio(1).clipShape(.capsule)
        let layout = node.layout(in: FLContext(width: 60, height: 200))

        #expect(layout.size == CGSize(width: 60, height: 60))
        #expect(FLShape.capsule.cornerRadius(in: layout.size) == 30)
    }

    @Test("a zero or negative ratio collapses rather than dividing by zero")
    func invalidRatio() {
        #expect(FLColor(.clear).aspectRatio(0).layout(in: FLContext(width: 300)).size == .zero)
        #expect(FLColor(.clear).aspectRatio(-2).layout(in: FLContext(width: 300)).size == .zero)
    }

    @Test("aspectRatio answers the proposal contract")
    func aspectRatioContract() {
        let node = FLColor(.clear).aspectRatio(2)

        #expect(node.layout(in: FLContext(width: .minimum)).size == .zero)
        #expect(node.layout(in: FLContext(width: .maximum, height: .maximum)).size.width == .infinity)
    }

    @Test("resizable and content mode participate in equality")
    func identity() {
        let image = wide

        #expect(FLImage(image) == FLImage(image))
        #expect(FLImage(image) != FLImage(image).resizable())
        #expect(FLImage(image) != FLImage(image, contentMode: .center))
    }

    @Test("an image composes with padding and a stack")
    func composes() {
        let node = FLVStack(spacing: 8) {
            FLColor(.clear).aspectRatio(2)
            FLText("caption")
                .font(.systemFont(ofSize: 12))
                .foregroundColor(.label)
        }
        .padding(10)

        let size = node.layout(in: FLContext(width: 220)).size

        // 220 - 20 padding = 200 wide, so 100 tall, plus spacing, caption and padding
        #expect(size.width == 220)
        #expect(size.height > 100 + 8 + 10 * 2)
    }
}

@Suite("Image tint")
struct FLImageTintTests {
    private var swatch: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }

    @Test("a tint does not affect measurement")
    func tintIsNotGeometry() {
        let plain = FLImage(swatch)
        let tinted = FLImage(swatch).tint(.systemRed)

        #expect(plain.layout(in: FLContext(width: 300)).size == tinted.layout(in: FLContext(width: 300)).size)
    }

    @Test("a tint participates in equality, so it re-renders")
    func tintAffectsIdentity() {
        let image = swatch

        #expect(FLImage(image) != FLImage(image).tint(.systemRed))
        #expect(FLImage(image).tint(.systemRed) == FLImage(image).tint(.systemRed))
        #expect(FLImage(image).tint(.systemRed) != FLImage(image).tint(.systemBlue))
        #expect(FLImage(image).tint(nil) == FLImage(image))
    }

    @Test("tint survives resizable and the initialiser form")
    func tintComposes() {
        #expect(FLImage(swatch, tintColor: .systemRed).tintColor == .systemRed)
        #expect(FLImage(swatch).tint(.systemRed).resizable().tintColor == .systemRed)
        #expect(FLImage(swatch).resizable().tint(.systemRed).isResizable)
    }
}
