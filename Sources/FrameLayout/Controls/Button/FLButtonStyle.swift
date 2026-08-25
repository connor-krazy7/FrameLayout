import UIKit

public struct FLButtonStyle: Hashable, Sendable {
    public let pressedOpacity: CGFloat
    public let pressedScale: CGFloat
    public let animation: FLAnimation

    private init(pressedOpacity: CGFloat, pressedScale: CGFloat, animation: FLAnimation) {
        self.pressedOpacity = pressedOpacity
        self.pressedScale = pressedScale
        self.animation = animation
    }

    public static func opacity(
        _ pressedOpacity: CGFloat = 0.6,
        animation: FLAnimation = .easeOut(0.12)
    ) -> FLButtonStyle {
        FLButtonStyle(pressedOpacity: pressedOpacity, pressedScale: 1, animation: animation)
    }

    public static func scaling(
        _ pressedScale: CGFloat = 0.96,
        opacity pressedOpacity: CGFloat = 1,
        animation: FLAnimation = .easeOut(0.12)
    ) -> FLButtonStyle {
        FLButtonStyle(pressedOpacity: pressedOpacity, pressedScale: pressedScale, animation: animation)
    }
}
