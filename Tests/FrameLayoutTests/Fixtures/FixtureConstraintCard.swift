import FrameLayout
import UIKit

enum FixtureCardMetrics {
    static var padding: CGFloat { 12 }
    static var iconSize: CGFloat { 24 }
    static var iconSpacing: CGFloat { 10 }
    static var titleSpacing: CGFloat { 2 }
    static var titleFont: UIFont { .systemFont(ofSize: 14, weight: .semibold) }
    static var subtitleFont: UIFont { .systemFont(ofSize: 12) }
    static var idealWidth: CGFloat { 260 }

    static var horizontalChrome: CGFloat { padding * 2 + iconSize + iconSpacing }
}

final class FixtureConstraintCardView: UIView {
    private let icon = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        icon.backgroundColor = .systemBlue
        titleLabel.font = FixtureCardMetrics.titleFont
        titleLabel.numberOfLines = 0
        subtitleLabel.font = FixtureCardMetrics.subtitleFont
        subtitleLabel.numberOfLines = 0

        for subview in [icon, titleLabel, subtitleLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        let metrics = FixtureCardMetrics.self

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: metrics.padding),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: metrics.iconSize),
            icon.heightAnchor.constraint(equalToConstant: metrics.iconSize),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: metrics.padding),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: metrics.iconSpacing),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -metrics.padding),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: metrics.titleSpacing),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -metrics.padding),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

struct FixtureConstraintCard: FLUIViewRepresentable {
    let title: String
    let subtitle: String

    func size(in context: FLContext) -> CGSize {
        let metrics = FixtureCardMetrics.self
        let width = context.width.resolved(ideal: metrics.idealWidth)
        let textWidth = max(0, width - metrics.horizontalChrome)
        let titleHeight = textHeight(title, font: metrics.titleFont, width: textWidth)
        let subtitleHeight = textHeight(subtitle, font: metrics.subtitleFont, width: textWidth)
        let stacked = titleHeight + metrics.titleSpacing + subtitleHeight

        return CGSize(width: width, height: metrics.padding * 2 + max(stacked, metrics.iconSize))
    }

    func makeView() -> FixtureConstraintCardView {
        FixtureConstraintCardView()
    }

    func update(_ view: FixtureConstraintCardView, previous: FixtureConstraintCard?, context: FLRenderContext) {
        view.configure(title: title, subtitle: subtitle)
    }

    private func textHeight(_ string: String, font: UIFont, width: CGFloat) -> CGFloat {
        FLText(string).font(font).layout(in: FLContext(width: width)).size.height
    }
}
