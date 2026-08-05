import UIKit

@MainActor
public struct FLRenderContext {
    public let environment: FLEnvironment
    public let registry: FLViewRegistry?
    public let animation: FLAnimation?
    public let isEnabled: Bool
    public let accessibilityLabel: String?

    public init(
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

    public func applying(_ overrides: FLEnvironmentOverrides) -> FLRenderContext {
        FLRenderContext(
            environment: environment.applying(overrides),
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    public func animating(_ animation: FLAnimation?) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    public func disabled(_ isDisabled: Bool) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled && !isDisabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    public func accessibilityLabel(_ accessibilityLabel: String?) -> FLRenderContext {
        FLRenderContext(
            environment: environment,
            registry: registry,
            animation: animation,
            isEnabled: isEnabled,
            accessibilityLabel: accessibilityLabel
        )
    }

    public func perform(_ changes: @escaping @MainActor () -> Void) {
        guard let animation else {
            changes()

            return
        }

        animation.run(changes)
    }
}
