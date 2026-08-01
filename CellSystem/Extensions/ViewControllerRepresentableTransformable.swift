import SwiftUI
import UIKit

@MainActor
protocol ViewControllerRepresentableTransformable {}

extension ViewControllerRepresentableTransformable where Self: UIViewController {
    static func asViewRepresentable(
        create: @escaping @MainActor @Sendable () -> Self = { Self() },
        setup: @escaping @MainActor @Sendable (_ uiViewController: Self) -> Void = { _ in },
        customise: @escaping @MainActor @Sendable (_ uiViewController: Self) -> Void = { _ in },
        calculateSize: @escaping @MainActor @Sendable (_ proposedSize: ProposedViewSize, _ uiViewController: Self) -> CGSize? = { _, _ in nil }
    ) -> some UIViewControllerRepresentable {
        ViewControllerRepresentableWrapper(
            create: create,
            setup: setup,
            customise: customise,
            calculateSize: calculateSize
        )
    }
}

extension UIViewController: ViewControllerRepresentableTransformable {}

private struct ViewControllerRepresentableWrapper<VC: UIViewController>: UIViewControllerRepresentable {
    let create: @MainActor @Sendable () -> VC
    let setup: @MainActor @Sendable (_ uiViewController: VC) -> Void
    let customise: @MainActor @Sendable (_ uiViewController: VC) -> Void
    let calculateSize: @MainActor @Sendable (_ proposedSize: ProposedViewSize, _ uiViewController: VC) -> CGSize?

    func makeUIViewController(context: Self.Context) -> VC {
        let uiViewController = create()
        setup(uiViewController)
        customise(uiViewController)
        return uiViewController
    }

    func updateUIViewController(_ uiViewController: VC, context: Context) {
        customise(uiViewController)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: VC, context: Context) -> CGSize? {
        calculateSize(proposal, uiViewController)
    }
}
