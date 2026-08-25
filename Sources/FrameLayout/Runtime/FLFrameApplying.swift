import UIKit

@MainActor
public protocol FLFrameApplying: UIView {
    func applyFrame(_ frame: CGRect)
}

public extension UIView {
    func flSetFrame(_ frame: CGRect, in context: FLRenderContext) {
        guard let applying = self as? any FLFrameApplying else {
            context.perform { self.frame = frame }

            return
        }

        applying.applyFrame(frame)
    }
}
