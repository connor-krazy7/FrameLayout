import SwiftUI

@MainActor
protocol ViewRepresentableTransformable {}

extension ViewRepresentableTransformable where Self: UIView {
    static func asViewRepresentable(
        setup: @escaping @MainActor @Sendable (_ uiView: Self) -> Void = { _ in },
        customise: @escaping @MainActor @Sendable (Self) -> Void = { _ in },
        calculateSize: @escaping @MainActor @Sendable (_ proposedSize: ProposedViewSize, _ uiView: Self) -> CGSize? = { _, _ in nil }
    ) -> some UIViewRepresentable {
        ViewRepresentableWrapper(setup: setup, customise: customise, calculateSize: calculateSize)
    }
}

extension UIView: ViewRepresentableTransformable {}

private struct ViewRepresentableWrapper<V: UIView>: UIViewRepresentable {
    let setup: @MainActor @Sendable (_ uiView: V) -> Void
    let customise: @MainActor @Sendable (_ uiView: V) -> Void
    let calculateSize: @MainActor @Sendable (_ proposedSize: ProposedViewSize, _ uiView: V) -> CGSize?

    func makeUIView(context: Context) -> V {
        let uiView = V()
        setup(uiView)
        customise(uiView)
        return uiView
    }

    func updateUIView(_ uiView: V, context: Context) {
        customise(uiView)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: V, context: Context) -> CGSize? {
        calculateSize(proposal, uiView)
    }
}
