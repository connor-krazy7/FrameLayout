import SwiftUI
import UIKit

struct DemoMember: Hashable, Sendable {
    let initials: String
    let color: UIColor
}

final class DemoAvatarStackView: UIView {
    private var badges: [UILabel] = []
    private var diameter: CGFloat = 28
    private var step: CGFloat = 18

    func configure(members: [DemoMember], diameter: CGFloat, overlap: CGFloat) {
        self.diameter = diameter
        step = diameter - overlap

        if badges.count != members.count {
            badges.forEach { $0.removeFromSuperview() }
            badges = members.map { _ in Self.makeBadge() }
            badges.forEach(addSubview)
        }

        for (badge, member) in zip(badges, members) {
            badge.text = member.initials
            badge.backgroundColor = member.color
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for (index, badge) in badges.enumerated() {
            badge.frame = CGRect(x: CGFloat(index) * step, y: 0, width: diameter, height: diameter)
            badge.layer.cornerRadius = diameter / 2
        }
    }

    private static func makeBadge() -> UILabel {
        let badge = UILabel()

        badge.textAlignment = .center
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .white
        badge.clipsToBounds = true
        badge.layer.borderWidth = 2
        badge.layer.borderColor = UIColor.systemBackground.cgColor

        return badge
    }
}

struct DemoAvatarStack: FLUIViewRepresentable {
    let members: [DemoMember]
    var diameter: CGFloat = 28
    var overlap: CGFloat = 10

    var naturalWidth: CGFloat {
        members.isEmpty ? 0 : diameter + CGFloat(members.count - 1) * (diameter - overlap)
    }

    func size(in context: FLContext) -> CGSize {
        CGSize(
            width: min(naturalWidth, context.width.resolved(ideal: naturalWidth)),
            height: min(diameter, context.height.resolved(ideal: diameter))
        )
    }

    func makeView() -> DemoAvatarStackView {
        DemoAvatarStackView()
    }

    func update(_ view: DemoAvatarStackView, previous: DemoAvatarStack?, context: FLRenderContext) {
        view.configure(members: members, diameter: diameter, overlap: overlap)
    }
}

final class DemoDelayedImageView: UIView {
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let caption = UILabel()
    private var task: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        caption.font = .systemFont(ofSize: 10, weight: .medium)
        caption.textColor = .white
        caption.textAlignment = .center
        caption.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        addSubview(imageView)
        addSubview(spinner)
        addSubview(caption)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView.frame = bounds
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
        caption.frame = CGRect(x: 0, y: bounds.maxY - 16, width: bounds.width, height: 16)
    }

    func load(_ image: UIImage?, named name: String, after delay: Duration) {
        cancel(status: "loading \(name)")

        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)

            guard let self, !Task.isCancelled else { return }

            imageView.image = image
            spinner.stopAnimating()
            caption.text = name
        }

        spinner.startAnimating()
    }

    func cancel(status: String) {
        task?.cancel()
        task = nil
        spinner.stopAnimating()
        imageView.image = nil
        caption.text = status
    }
}

struct DemoDelayedThumbnail: FLUIViewRepresentable {
    let name: String
    let pixelSize: CGSize
    let color: UIColor
    var delay: Duration = .milliseconds(900)

    func size(in context: FLContext) -> CGSize {
        let width = min(pixelSize.width, context.width.resolved(ideal: pixelSize.width))

        return CGSize(width: width, height: width * pixelSize.height / pixelSize.width)
    }

    func makeView() -> DemoDelayedImageView {
        DemoDelayedImageView()
    }

    func update(_ view: DemoDelayedImageView, previous: DemoDelayedThumbnail?, context: FLRenderContext) {
        guard previous?.name != name else { return }

        view.load(FLImageSamples.swatch(size: pixelSize, color: color), named: name, after: delay)
    }

    func onDetach(_ view: DemoDelayedImageView) {
        view.cancel(status: "cancelled")
    }
}

enum DemoInfoCardMetrics {
    static var padding: CGFloat { 12 }
    static var iconSize: CGFloat { 24 }
    static var iconSpacing: CGFloat { 10 }
    static var chevronSize: CGFloat { 12 }
    static var chevronSpacing: CGFloat { 8 }
    static var titleSpacing: CGFloat { 2 }
    static var titleFont: UIFont { .systemFont(ofSize: 14, weight: .semibold) }
    static var subtitleFont: UIFont { .systemFont(ofSize: 12) }
    static var idealWidth: CGFloat { 260 }

    static var horizontalChrome: CGFloat {
        padding * 2 + iconSize + iconSpacing + chevronSize + chevronSpacing
    }
}

final class DemoInfoCardView: UIView {
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        icon.contentMode = .scaleAspectFit
        icon.tintColor = .systemBlue
        chevron.contentMode = .scaleAspectFit
        chevron.tintColor = .tertiaryLabel
        chevron.image = UIImage(systemName: "chevron.right")
        titleLabel.font = DemoInfoCardMetrics.titleFont
        titleLabel.numberOfLines = 0
        subtitleLabel.font = DemoInfoCardMetrics.subtitleFont
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        for subview in [icon, titleLabel, subtitleLabel, chevron] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subview)
        }

        let metrics = DemoInfoCardMetrics.self

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: metrics.padding),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: metrics.iconSize),
            icon.heightAnchor.constraint(equalToConstant: metrics.iconSize),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -metrics.padding),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: metrics.chevronSize),
            chevron.heightAnchor.constraint(equalToConstant: metrics.chevronSize),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: metrics.padding),
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: metrics.iconSpacing),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -metrics.chevronSpacing),

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

    func configure(symbol: String, title: String, subtitle: String) {
        icon.image = UIImage(systemName: symbol)
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

struct DemoInfoCard: FLUIViewRepresentable {
    let symbol: String
    let title: String
    let subtitle: String

    func size(in context: FLContext) -> CGSize {
        let metrics = DemoInfoCardMetrics.self
        let width = context.width.resolved(ideal: metrics.idealWidth)
        let textWidth = max(0, width - metrics.horizontalChrome)
        let titleHeight = textHeight(title, font: metrics.titleFont, width: textWidth)
        let subtitleHeight = textHeight(subtitle, font: metrics.subtitleFont, width: textWidth)
        let stacked = titleHeight + metrics.titleSpacing + subtitleHeight

        return CGSize(
            width: width,
            height: metrics.padding * 2 + max(stacked, metrics.iconSize)
        )
    }

    func makeView() -> DemoInfoCardView {
        DemoInfoCardView()
    }

    func update(_ view: DemoInfoCardView, previous: DemoInfoCard?, context: FLRenderContext) {
        view.configure(symbol: symbol, title: title, subtitle: subtitle)
    }

    private func textHeight(_ string: String, font: UIFont, width: CGFloat) -> CGFloat {
        FLText(string).font(font).layout(in: FLContext(width: width)).size.height
    }
}

private struct RepresentableRow: FLView {
    let members: [DemoMember]
    let thumbnail: DemoDelayedThumbnail?
    let card: DemoInfoCard

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 10) {
            FLText("Design review")
                .font(.systemFont(ofSize: 15, weight: .semibold))

            DemoAvatarStack(members: members)
                .padding(4)
                .background(.secondarySystemBackground, in: .roundedRectangle(18))
                .tag("avatars")

            card
                .background(.secondarySystemBackground, in: .roundedRectangle(12))
                .tag("card")

            if let thumbnail {
                thumbnail
                    .background(.tertiarySystemFill, in: .roundedRectangle(10))
                    .clipped()
                    .tag("thumbnail")
            }
        }
        .padding(14)
        .background(.systemBackground, in: .roundedRectangle(16))
    }
}

private struct RepresentablePlayground: View {
    private static var everyone: [DemoMember] {
        [
            DemoMember(initials: "AP", color: .systemBlue),
            DemoMember(initials: "KM", color: .systemPink),
            DemoMember(initials: "JR", color: .systemPurple),
            DemoMember(initials: "TS", color: .systemTeal),
            DemoMember(initials: "LW", color: .systemOrange),
        ]
    }

    private static var subtitles: [String] {
        [
            "one line",
            "a subtitle long enough to wrap onto a second line inside the constraint-driven card",
            "two words",
            "another subtitle that runs on far enough to need more than a single line of layout",
            "short",
        ]
    }

    private var subtitles: [String] { Self.subtitles }

    @State private var memberCount = 3
    @State private var showsThumbnail = true
    @State private var photoIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("the avatar stack lays out by frames, the card by constraints — both injected with FLUIViewRepresentable, both declaring their own size")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(measured)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                FLNodePreview(node: row.node, layoutContext: FLContext(width: 300))
                    .border(.blue.opacity(0.4))

                controls
            }
            .padding(20)
        }
    }

    private var row: RepresentableRow {
        RepresentableRow(
            members: Array(Self.everyone.prefix(memberCount)),
            thumbnail: showsThumbnail ? thumbnail : nil,
            card: DemoInfoCard(
                symbol: "person.2.fill",
                title: "\(memberCount) reviewers assigned",
                subtitle: subtitles[memberCount % subtitles.count]
            )
        )
    }

    private var thumbnail: DemoDelayedThumbnail {
        let photos = [
            ("mockups", CGSize(width: 240, height: 135), UIColor.systemIndigo),
            ("whiteboard", CGSize(width: 200, height: 200), UIColor.systemGreen),
            ("logo", CGSize(width: 120, height: 160), UIColor.systemRed),
        ]
        let photo = photos[photoIndex % photos.count]

        return DemoDelayedThumbnail(name: photo.0, pixelSize: photo.1, color: photo.2)
    }

    private var measured: String {
        let size = row.node.layout(in: FLContext(width: 300)).size

        return "row reserves \(Int(size.width)) × \(Int(size.height)) in a 300pt box"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("members: \(memberCount)", value: $memberCount, in: 1...5)
                .font(.system(size: 12))

            Toggle("show thumbnail", isOn: $showsThumbnail)
                .font(.system(size: 12))

            Button("load a different photo") {
                photoIndex += 1
            }
            .font(.system(size: 12))

            Text("hiding the thumbnail leaves the window, which cancels the load; showing it again starts over")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("representable: injected UIKit views") {
    RepresentablePlayground()
}
