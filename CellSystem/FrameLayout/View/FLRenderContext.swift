import UIKit

@MainActor
struct FLRenderContext {
    let environment: FLEnvironment
    let registry: FLViewRegistry?
    let animation: FLAnimation?
    let isEnabled: Bool
    let accessibilityLabel: String?

    init(
        environment: FLEnvironment = .default,
        registry: FLViewRegistry? = nil,
        animation: FLAnimation? = nil,
        isEnabled: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        self.environment = environment
        self.registry = registry
        self.animation = animation
        self.isEnabled = isEnabled
        self.accessibilityLabel = accessibilityLabel
    }

    func applying(_ overrides: FLEnvironmentOverrides) -> FLRenderContext {
        FLRenderContext(
            environment: environment.applying(overrides),
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    func animating(_ animation: FLAnimation?) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    func disabled(_ isDisabled: Bool) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled && !isDisabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    func accessibilityLabel(_ accessibilityLabel: String?) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    func perform(_ changes: @escaping @MainActor () -> Void) {
        guard let animation else {
            changes()

            return
        }

        animation.run(changes)
    }
}
