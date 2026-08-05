import UIKit

public struct FLAnimation: Hashable, Sendable {
    public enum Timing: Hashable, Sendable {
        case linear
        case easeIn
        case easeOut
        case easeInOut
        case spring(damping: CGFloat, initialVelocity: CGFloat)

        var options: UIView.AnimationOptions {
            switch self {
            case .linear: .curveLinear
            case .easeIn: .curveEaseIn
            case .easeOut: .curveEaseOut
            case .easeInOut, .spring: .curveEaseInOut
            }
        }

        var spring: (damping: CGFloat, initialVelocity: CGFloat)? {
            guard case let .spring(damping, initialVelocity) = self else { return nil }

            return (damping, initialVelocity)
        }
    }

    public var duration: TimeInterval
    public var timing: Timing
    public var delay: TimeInterval

    public init(duration: TimeInterval, timing: Timing = .easeInOut, delay: TimeInterval = 0) {
        self.duration = duration
        self.timing = timing
        self.delay = delay
    }

    public static func linear(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .linear)
    }

    public static func easeInOut(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .easeInOut)
    }

    public static func easeOut(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .easeOut)
    }

    public static func spring(
        _ duration: TimeInterval = 0.5,
        damping: CGFloat = 0.8,
        initialVelocity: CGFloat = 0
    ) -> FLAnimation {
        FLAnimation(duration: duration, timing: .spring(damping: damping, initialVelocity: initialVelocity))
    }
}

public extension FLAnimation {
    @MainActor
    func run(
        _ changes: @escaping @MainActor () -> Void,
        completion: (@MainActor (Bool) -> Void)? = nil
    ) {
        let options: UIView.AnimationOptions = [
            timing.options,
            .overrideInheritedDuration,
            .overrideInheritedCurve,
            .allowUserInteraction,
        ]

        guard let spring = timing.spring else {
            UIView.animate(
                withDuration: duration,
                delay: delay,
                options: options,
                animations: changes,
                completion: completion
            )

            return
        }

        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: spring.damping,
            initialSpringVelocity: spring.initialVelocity,
            options: options,
            animations: changes,
            completion: completion
        )
    }
}
