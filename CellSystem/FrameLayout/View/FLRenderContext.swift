import UIKit

@MainActor
struct FLRenderContext {
    let environment: FLEnvironment
    let registry: FLViewRegistry?
    let animation: FLAnimation?

    init(
        environment: FLEnvironment = .default,
        registry: FLViewRegistry? = nil,
        animation: FLAnimation? = nil
    ) {
        self.environment = environment
        self.registry = registry
        self.animation = animation
    }

    func applying(_ overrides: FLEnvironmentOverrides) -> FLRenderContext {
        FLRenderContext(
            environment: environment.applying(overrides),
            registry: registry,
            animation: animation
        )
    }

    func animating(_ animation: FLAnimation?) -> FLRenderContext {
        FLRenderContext(environment: environment, registry: registry, animation: animation)
    }

    func perform(_ changes: @escaping @MainActor () -> Void) {
        guard let animation else {
            changes()

            return
        }

        animation.run(changes)
    }
}
