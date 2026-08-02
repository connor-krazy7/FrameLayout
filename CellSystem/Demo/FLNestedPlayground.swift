import SwiftUI
import UIKit

struct DemoAuthor: Hashable, Sendable {
    let id: String
    let name: String
    let initials: String
}

struct DemoAttachment: Identifiable, Hashable, Sendable {
    let id: String
    let symbol: String
    let title: String
    let detail: String
}

struct DemoReactionSummary: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let count: Int
    let isMine: Bool
}

struct DemoPhoto: Hashable, Sendable {
    let id: String
    let symbol: String
    let pixelSize: CGSize

    var ratio: CGFloat { pixelSize.height > 0 ? pixelSize.width / pixelSize.height : 1 }
}

struct DemoReplyContext: Hashable, Sendable {
    let author: String
    let snippet: String
}

enum DemoDelivery: Hashable, Sendable {
    case sending
    case sent
    case failed
}

struct DemoMessage: Identifiable, Hashable, Sendable {
    let id: String
    let author: DemoAuthor
    let text: String
    let replyContext: DemoReplyContext?
    let photo: DemoPhoto?
    let attachments: [DemoAttachment]
    let reactions: [DemoReactionSummary]
    let delivery: DemoDelivery
}

enum DemoMessagePart: Hashable, Sendable {
    case avatar(String)
    case bubble(String)
    case retry(String)
    case attachment(String)
    case photo(String)
}

struct DemoConversationPhoto: FLView {
    static var maximumHeight: CGFloat { 220 }

    let photo: DemoPhoto

    var body: some FLNode {
        FLImage(UIImage(systemName: photo.symbol))
            .resizable()
            .foregroundColor(.white)
            .aspectRatio(
                photo.ratio,
                contentMode: .fit,
                maxWidth: photo.pixelSize.width,
                maxHeight: Self.maximumHeight
            )
            .background(.white.withAlphaComponent(0.15), in: .roundedRectangle(12))
            .clipped()
    }
}

struct DemoMessageAvatar: FLView {
    let author: DemoAuthor

    var body: some FLNode {
        FLText(author.initials)
            .font(.systemFont(ofSize: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(.systemIndigo, in: .capsule)
    }
}

struct DemoReplyPreview: FLView {
    let context: DemoReplyContext

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 8) {
            FLColor(.systemBlue).frame(width: 3, height: 32).clipShape(.roundedRectangle(1.5))

            FLVStack(alignment: .leading, spacing: 2) {
                FLText(context.author)
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.systemBlue)

                FLText(context.snippet)
                    .font(.systemFont(ofSize: 12))
                    .foregroundColor(.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.tertiarySystemFill, in: .roundedRectangle(8))
    }
}

struct DemoAttachmentRow: FLView {
    let attachment: DemoAttachment

    var body: some FLNode {
        FLHStack(spacing: 8) {
            FLImage(UIImage(systemName: attachment.symbol))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)

            FLVStack(alignment: .leading, spacing: 1) {
                FLText(attachment.title)
                    .font(.systemFont(ofSize: 13, weight: .medium))
                    .foregroundColor(.white)

                FLText(attachment.detail)
                    .font(.systemFont(ofSize: 11))
                    .foregroundColor(.white)
                    .opacity(0.7)
            }

            FLSpacer()
        }
        .padding(8)
        .background(.white.withAlphaComponent(0.15), in: .roundedRectangle(8))
    }
}

struct DemoMessageReactionChip: FLView {
    let reaction: DemoReactionSummary

    var body: some FLNode {
        FLHStack(spacing: 4) {
            FLText(reaction.emoji).font(.systemFont(ofSize: 12))
            FLText("\(reaction.count)")
                .font(.systemFont(ofSize: 12, weight: .semibold))
                .foregroundColor(reaction.isMine ? .white : .label)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(reaction.isMine ? .systemBlue : .secondarySystemFill, in: .capsule)
    }
}

struct DemoMessageBubble: FLView {
    let message: DemoMessage

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            if let replyContext = message.replyContext {
                DemoReplyPreview(context: replyContext)
            }

            FLText(message.text)
                .font(.systemFont(ofSize: 15))
                .foregroundColor(.white)

            if let photo = message.photo {
                DemoConversationPhoto(photo: photo)
                    .tag(DemoMessagePart.photo(message.id))
            }

            FLForEach(message.attachments) { attachment in
                DemoAttachmentRow(attachment: attachment)
            }
        }
        .padding(12)
        .background(.systemBlue, in: .roundedRectangle(16))
        .tag(DemoMessagePart.bubble(message.id))
    }
}

struct DemoMessageFooter: FLView {
    let message: DemoMessage

    var body: some FLNode {
        FLHStack(spacing: 6) {
            FLForEach(message.reactions) { reaction in
                DemoMessageReactionChip(reaction: reaction)
            }

            if message.delivery == .failed {
                FLButton(tag: DemoMessagePart.retry(message.id), style: .scaling(0.94)) {
                    FLText("Retry")
                        .font(.systemFont(ofSize: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.systemRed, in: .capsule)
                }
                .accessibilityLabel("Retry sending")
            }

            FLSpacer()

            FLText(message.delivery == .sending ? "sending…" : "09:41")
                .font(.systemFont(ofSize: 11))
                .foregroundColor(.tertiaryLabel)
        }
    }
}

struct DemoNestedMessageRow: FLView {
    let message: DemoMessage

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 10) {
            DemoMessageAvatar(author: message.author)
                .tag(DemoMessagePart.avatar(message.id))

            FLVStack(alignment: .leading, spacing: 6) {
                FLText(message.author.name)
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.secondaryLabel)

                DemoMessageBubble(message: message)
                    .animation(.easeInOut(0.2), value: message.attachments)

                DemoMessageFooter(message: message)
            }
        }
        .opacity(message.delivery == .sending ? 0.6 : 1)
        .animation(.easeInOut(0.25), value: message)
    }
}

@MainActor
final class FLNestedPlaygroundViewController: UIViewController {
    private let scrollView = UIScrollView().then { $0.translatesAutoresizingMaskIntoConstraints = false }
    private let rows = UIStackView().then {
        $0.axis = .vertical
        $0.spacing = 20
        $0.alignment = .fill
        $0.translatesAutoresizingMaskIntoConstraints = false
    }
    private let readout = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.textColor = .secondaryLabel
    }

    private var messages = DemoMessage.samples
    private var hosts: [String: FLHost<DemoNestedMessageRow>] = [:]
    private var nextReaction = 0
    private var nextAttachment = 0
    private var nextPhoto = -1

    private static let photoShapes: [DemoPhoto?] = [
        nil,
        DemoPhoto(id: "landscape", symbol: "photo.fill", pixelSize: CGSize(width: 1600, height: 900)),
        DemoPhoto(id: "portrait", symbol: "person.fill", pixelSize: CGSize(width: 900, height: 1600)),
        DemoPhoto(id: "tiny", symbol: "seal.fill", pixelSize: CGSize(width: 80, height: 60)),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        for message in messages {
            let host = FLHost<DemoNestedMessageRow>()

            hosts[message.id] = host
            rows.addArrangedSubview(host)
        }

        let controls = UIStackView(arrangedSubviews: [buttons(), readout]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        scrollView.addSubview(rows)
        view.addSubview(scrollView)
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -12),

            rows.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            rows.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            rows.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        bindActions()
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard hosts.values.first?.contentSize.width == 0, view.bounds.width > 0 else { return }

        reload()
    }

    private func reload() {
        let width = max(1, view.bounds.width - 32)

        UIView.animate(withDuration: 0.25) {
            for message in self.messages {
                guard let host = self.hosts[message.id] else { continue }

                let node = DemoNestedMessageRow(message: message).node

                host.apply(node: node, layout: node.layout(in: FLContext(width: width)))
            }
        }

        readout.text = messages
            .map { message in
                let host = hosts[message.id]
                let parts = host.map { $0.registry.count } ?? 0

                let photoBox = host?.registry.view(withTag: DemoMessagePart.photo(message.id))?.bounds.size

                return "\(message.id)  \(Int(host?.contentSize.height ?? 0))pt   "
                    + "\(message.attachments.count) attachments, \(message.reactions.count) reactions, "
                    + "\(parts) tagged parts"
                    + (photoBox.map { ", photo \(Int($0.width))x\(Int($0.height))" } ?? "")
            }
            .joined(separator: "\n")
    }

    private func bindActions() {
        for message in messages {
            hosts[message.id]?.registry.bindAction(withTag: DemoMessagePart.retry(message.id)) { [weak self] _ in
                self?.markSent(message.id)
            }
        }
    }

    private func markSent(_ id: String) {
        mutate(id) { message in
            DemoMessage(
                id: message.id,
                author: message.author,
                text: message.text,
                replyContext: message.replyContext,
                photo: message.photo,
                attachments: message.attachments,
                reactions: message.reactions,
                delivery: .sent
            )
        }
    }

    private func mutate(_ id: String, _ transform: (DemoMessage) -> DemoMessage) {
        messages = messages.map { $0.id == id ? transform($0) : $0 }
        reload()
    }

    private func buttons() -> UIStackView {
        let reaction = UIButton(configuration: .bordered()).then { $0.setTitle("+ reaction", for: .normal) }
        let attachment = UIButton(configuration: .bordered()).then { $0.setTitle("+ attachment", for: .normal) }
        let reply = UIButton(configuration: .bordered()).then { $0.setTitle("reply", for: .normal) }
        let fail = UIButton(configuration: .bordered()).then { $0.setTitle("fail", for: .normal) }
        let photo = UIButton(configuration: .bordered()).then { $0.setTitle("photo", for: .normal) }

        photo.addAction(
            UIAction { [weak self] _ in
                guard let self, let first = messages.first else { return }

                nextPhoto += 1
                mutate(first.id) { message in
                    DemoMessage(
                        id: message.id,
                        author: message.author,
                        text: message.text,
                        replyContext: message.replyContext,
                        photo: Self.photoShapes[self.nextPhoto % Self.photoShapes.count],
                        attachments: message.attachments,
                        reactions: message.reactions,
                        delivery: message.delivery
                    )
                }
            },
            for: .touchUpInside
        )

        reaction.addAction(
            UIAction { [weak self] _ in
                guard let self, let first = messages.first else { return }

                let added = DemoReactionSummary(
                    id: "r\(nextReaction)",
                    emoji: ["🎉", "🔥", "👀", "🙏"][nextReaction % 4],
                    count: nextReaction + 1,
                    isMine: nextReaction.isMultiple(of: 2)
                )

                nextReaction += 1
                mutate(first.id) { message in
                    DemoMessage(
                        id: message.id,
                        author: message.author,
                        text: message.text,
                        replyContext: message.replyContext,
                        photo: message.photo,
                        attachments: message.attachments,
                        reactions: message.reactions + [added],
                        delivery: message.delivery
                    )
                }
            },
            for: .touchUpInside
        )

        attachment.addAction(
            UIAction { [weak self] _ in
                guard let self, let first = messages.first else { return }

                let added = DemoAttachment(
                    id: "a\(nextAttachment)",
                    symbol: ["doc.fill", "photo.fill", "map.fill"][nextAttachment % 3],
                    title: "Attachment \(nextAttachment + 1)",
                    detail: "\(120 + nextAttachment * 37) KB"
                )

                nextAttachment += 1
                mutate(first.id) { message in
                    DemoMessage(
                        id: message.id,
                        author: message.author,
                        text: message.text,
                        replyContext: message.replyContext,
                        photo: message.photo,
                        attachments: message.attachments + [added],
                        reactions: message.reactions,
                        delivery: message.delivery
                    )
                }
            },
            for: .touchUpInside
        )

        reply.addAction(
            UIAction { [weak self] _ in
                guard let self, let first = messages.first else { return }

                mutate(first.id) { message in
                    DemoMessage(
                        id: message.id,
                        author: message.author,
                        text: message.text,
                        replyContext: message.replyContext == nil
                            ? DemoReplyContext(author: "Ann", snippet: "are we still on for tomorrow?")
                            : nil,
                        photo: message.photo,
                        attachments: message.attachments,
                        reactions: message.reactions,
                        delivery: message.delivery
                    )
                }
            },
            for: .touchUpInside
        )

        fail.addAction(
            UIAction { [weak self] _ in
                guard let self, let first = messages.first else { return }

                mutate(first.id) { message in
                    DemoMessage(
                        id: message.id,
                        author: message.author,
                        text: message.text,
                        replyContext: message.replyContext,
                        photo: message.photo,
                        attachments: message.attachments,
                        reactions: message.reactions,
                        delivery: message.delivery == .failed ? .sent : .failed
                    )
                }
            },
            for: .touchUpInside
        )

        return UIStackView(arrangedSubviews: [reaction, attachment, reply, fail, photo]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.distribution = .fillProportionally
        }
    }
}

extension DemoMessage {
    static var samples: [DemoMessage] {
        [
            DemoMessage(
                id: "m1",
                author: DemoAuthor(id: "u1", name: "Ann Petrova", initials: "AP"),
                text: "Every level here is its own FLView, and the data is nested to match.",
                replyContext: nil,
                photo: nil,
                attachments: [],
                reactions: [DemoReactionSummary(id: "seed", emoji: "❤️", count: 2, isMine: false)],
                delivery: .sent
            ),
            DemoMessage(
                id: "m2",
                author: DemoAuthor(id: "u2", name: "Marek Nowak", initials: "MN"),
                text: "This one starts with a reply and an attachment.",
                replyContext: DemoReplyContext(author: "Ann Petrova", snippet: "Every level here is its own FLView"),
                photo: DemoPhoto(id: "p1", symbol: "photo.fill", pixelSize: CGSize(width: 1600, height: 900)),
                attachments: [DemoAttachment(id: "seed", symbol: "doc.fill", title: "Spec.pdf", detail: "412 KB")],
                reactions: [],
                delivery: .failed
            ),
            DemoMessage(
                id: "m3",
                author: DemoAuthor(id: "u3", name: "Yuki Tanaka", initials: "YT"),
                text: "Still sending.",
                replyContext: nil,
                photo: nil,
                attachments: [],
                reactions: [],
                delivery: .sending
            ),
        ]
    }
}

#Preview("nested composites") {
    FLNestedPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
