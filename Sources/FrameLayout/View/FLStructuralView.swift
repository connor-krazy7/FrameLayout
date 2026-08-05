import UIKit

public class FLStructuralView: UIView {
    public var drawsContent = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        guard hitView === self, !drawsContent, !acceptsTouches else { return hitView }

        return nil
    }

    private var acceptsTouches: Bool {
        !(gestureRecognizers ?? []).isEmpty || !interactions.isEmpty
    }
}
