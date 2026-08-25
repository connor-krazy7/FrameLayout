import Testing
import UIKit
@testable import FrameLayout

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
        let tinted = FLImage(swatch).foregroundColor(.systemRed)

        #expect(plain.layout(in: FLContext(width: 300)).size == tinted.layout(in: FLContext(width: 300)).size)
    }

    @Test("a tint participates in equality, so it re-renders")
    func tintAffectsIdentity() {
        let image = swatch

        #expect(FLImage(image) != FLImage(image).foregroundColor(.systemRed))
        #expect(FLImage(image).foregroundColor(.systemRed) == FLImage(image).foregroundColor(.systemRed))
        #expect(FLImage(image).foregroundColor(.systemRed) != FLImage(image).foregroundColor(.systemBlue))
        #expect(FLImage(image).foregroundColor(nil) == FLImage(image))
    }

    @Test("tint survives resizable and the initialiser form")
    func tintComposes() {
        #expect(FLImage(swatch).foregroundColor(.systemRed).overrides.foregroundColor == .systemRed)
        #expect(FLImage(swatch).foregroundColor(.systemRed).resizable().overrides.foregroundColor == .systemRed)
        #expect(FLImage(swatch).resizable().foregroundColor(.systemRed).isResizable)
    }
}
