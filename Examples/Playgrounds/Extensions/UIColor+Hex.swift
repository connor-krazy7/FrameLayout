import UIKit

extension UIColor {
    convenience init(hex value: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(white: CGFloat) {
        self.init(white: white, alpha: 1)
    }
}
