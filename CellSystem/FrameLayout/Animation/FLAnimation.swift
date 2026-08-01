import UIKit

struct FLAnimation: Hashable, Sendable {
    enum Timing: Hashable, Sendable {
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

    var duration: TimeInterval
    var timing: Timing
    var delay: TimeInterval

    init(duration: TimeInterval, timing: Timing = .easeInOut, delay: TimeInterval = 0) {
        self.duration = duration
        self.timing = timing
        self.delay = delay
    }

    static func linear(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .linear)
    }

    static func easeInOut(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .easeInOut)
    }

    static func easeOut(_ duration: TimeInterval = 0.3) -> FLAnimation {
        FLAnimation(duration: duration, timing: .easeOut)
    }

    static func spring(
        _ duration: TimeInterval = 0.5,
        damping: CGFloat = 0.8,
        initialVelocity: CGFloat = 0
    ) -> FLAnimation {
        FLAnimation(duration: duration, timing: .spring(damping: damping, initialVelocity: initialVelocity))
    }
}

extension FLAnimation {
    @MainActor
    func run(_ changes: @escaping @MainActor () -> Void) {
        let options: UIView.AnimationOptions = [
            timing.options,
            .overrideInheritedDuration,
            .overrideInheritedCurve,
            .allowUserInteraction,
        ]

        guard let spring = timing.spring else {
            UIView.animate(withDuration: duration, delay: delay, options: options, animations: changes)

            return
        }

        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: spring.damping,
            initialSpringVelocity: spring.initialVelocity,
            options: options,
            animations: changes
        )
    }
}
