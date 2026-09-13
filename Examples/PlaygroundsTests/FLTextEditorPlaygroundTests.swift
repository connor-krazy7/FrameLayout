import Testing
import UIKit

@testable import FrameLayout
@testable import Playgrounds

@MainActor
@Suite("Text editor playground")
struct FLTextEditorPlaygroundTests {
    private func presented() -> (UIWindow, FLTextEditorPlaygroundViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let controller = FLTextEditorPlaygroundViewController()

        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        controller.viewDidLayoutSubviews()
        controller.view.layoutIfNeeded()

        return (window, controller)
    }

    @Test("the compose box takes a tap anywhere inside it")
    func composeBoxIsTappable() {
        let (window, controller) = presented()
        let input = firstInput(in: controller.view)
        let box = input.map { $0.convert($0.bounds, to: window) } ?? .zero
        let points = [
            CGPoint(x: box.minX + 2, y: box.minY + 2),
            CGPoint(x: box.midX, y: box.midY),
            CGPoint(x: box.maxX - 2, y: box.maxY - 2)
        ]

        #expect(input != nil)
        #expect(box.width > 0 && box.height > 0)

        for point in points {
            let hit = window.hitTest(point, with: nil)
            let reachesEditor = hit === input || hit.map { $0.isDescendant(of: input ?? UIView()) } == true

            #expect(reachesEditor, "tap at \(point) landed on \(String(describing: hit))")
        }
    }

    private func firstInput(in view: UIView) -> FLTextEditorInput? {
        if let input = view as? FLTextEditorInput { return input }

        for subview in view.subviews {
            if let found = firstInput(in: subview) { return found }
        }

        return nil
    }
}
