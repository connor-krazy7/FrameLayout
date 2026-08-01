import UIKit

@MainActor
struct FLRenderContext {
    let environment: FLEnvironment
    let registry: FLViewRegistry?

    init(environment: FLEnvironment = .default, registry: FLViewRegistry? = nil) {
        self.environment = environment
        self.registry = registry
    }

    func applying(_ overrides: FLEnvironmentOverrides) -> FLRenderContext {
        FLRenderContext(environment: environment.applying(overrides), registry: registry)
    }
}
