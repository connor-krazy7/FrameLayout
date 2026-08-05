import UIKit

enum FixtureSwatch {
    static var boxWidth: CGFloat { 160 }

    static var landscape: UIImage { image(size: CGSize(width: 160, height: 90), color: .systemBlue) }
    static var portrait: UIImage { image(size: CGSize(width: 60, height: 120), color: .systemPink) }
    static var tiny: UIImage { image(size: CGSize(width: 40, height: 30), color: .systemGreen) }

    static var photoSizes: [CGSize] {
        [
            CGSize(width: 1600, height: 900),
            CGSize(width: 900, height: 1600),
            CGSize(width: 800, height: 800),
            CGSize(width: 2400, height: 600),
            CGSize(width: 60, height: 40),
        ]
    }

    static func image(size: CGSize, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.9).setStroke()
            context.cgContext.setLineWidth(4)
            context.cgContext.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6))
        }
    }
}
