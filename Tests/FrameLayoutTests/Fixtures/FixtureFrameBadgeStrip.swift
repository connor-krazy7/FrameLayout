import FrameLayout
import UIKit

final class FixtureBadgeStripView: UIView {
    private var dots: [UIView] = []
    private var diameter: CGFloat = 20
    private var step: CGFloat = 14

    func configure(count: Int, diameter: CGFloat, overlap: CGFloat) {
        self.diameter = diameter
        step = diameter - overlap

        if dots.count != count {
            dots.forEach { $0.removeFromSuperview() }
            dots = (0..<count).map { _ in UIView() }
            dots.forEach {
                $0.backgroundColor = .systemBlue
                addSubview($0)
            }
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for (index, dot) in dots.enumerated() {
            dot.frame = CGRect(x: CGFloat(index) * step, y: 0, width: diameter, height: diameter)
            dot.layer.cornerRadius = diameter / 2
        }
    }
}

struct FixtureBadgeStrip: FLUIViewRepresentable {
    let count: Int
    var diameter: CGFloat = 20
    var overlap: CGFloat = 6

    var naturalWidth: CGFloat {
        count == 0 ? 0 : diameter + CGFloat(count - 1) * (diameter - overlap)
    }

    func size(in context: FLContext) -> CGSize {
        CGSize(
            width: min(naturalWidth, context.width.resolved(ideal: naturalWidth)),
            height: min(diameter, context.height.resolved(ideal: diameter))
        )
    }

    func makeView() -> FixtureBadgeStripView {
        FixtureBadgeStripView()
    }

    func update(_ view: FixtureBadgeStripView, previous: FixtureBadgeStrip?, context: FLRenderContext) {
        view.configure(count: count, diameter: diameter, overlap: overlap)
    }
}
