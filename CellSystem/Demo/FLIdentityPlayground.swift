import SwiftUI
import UIKit

enum DemoRowPart: Hashable, Sendable, CaseIterable {
    case avatar
    case replyPreview
    case bubble
    case retry

    var title: String {
        switch self {
        case .avatar: "avatar"
        case .replyPreview: "reply preview"
        case .bubble: "bubble"
        case .retry: "retry"
        }
    }
}

struct DemoMessageRow: FLView {
    let text: String
    let replyingTo: String?
    let hasFailed: Bool

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 10) {
            FLColor(.systemGray3)
                .frame(width: 36, height: 36)
                .clipShape(.capsule)
                .tag(DemoRowPart.avatar)

            FLVStack(alignment: .leading, spacing: 6) {
                if let replyingTo {
                    FLText(replyingTo)
                        .lineLimit(1)
                        .font(.systemFont(ofSize: 13))
                        .foregroundColor(.secondaryLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.tertiarySystemFill, in: .roundedRectangle(8))
                        .tag(DemoRowPart.replyPreview)
                }

                FLText(text)
                    .font(.systemFont(ofSize: 16))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.systemBlue, in: .roundedRectangle(16))
                    .tag(DemoRowPart.bubble)

                if hasFailed {
                    FLText("Tap to retry")
                        .font(.systemFont(ofSize: 12, weight: .semibold))
                        .foregroundColor(.systemRed)
                        .padding(.vertical, 4)
                        .tag(DemoRowPart.retry)
                }
            }

            FLSpacer()
        }
        .padding(16)
    }
}

@MainActor
final class FLIdentityPlaygroundViewController: UIViewController {
    private let host = FLHost<DemoMessageRow>()
    private let logLabel = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        $0.textColor = .secondaryLabel
    }
    private let registeredLabel = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        $0.textColor = .label
    }
    private let replyToggle = UISwitch().then { $0.isOn = true }
    private let failureToggle = UISwitch()

    private var events: [String] = []
    private var showsReply = true
    private var hasFailed = false

    private var row: DemoMessageRow {
        DemoMessageRow(
            text: "Tap the avatar, long-press the bubble, swipe it left. Tap the gap and nothing fires.",
            replyingTo: showsReply ? "Replying to Ann: are we still on for tomorrow?" : nil,
            hasFailed: hasFailed
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let toggles = UIStackView(arrangedSubviews: [
            Self.toggleRow(title: "replying to someone", control: replyToggle),
            Self.toggleRow(title: "delivery failed", control: failureToggle),
        ]).then {
            $0.axis = .vertical
            $0.spacing = 4
            $0.alignment = .fill
        }

        let stack = UIStackView(arrangedSubviews: [host, toggles, registeredLabel, logLabel]).then {
            $0.axis = .vertical
            $0.spacing = 16
            $0.alignment = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        replyToggle.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                showsReply = replyToggle.isOn
                reload()
                log("\(showsReply ? "added" : "removed")     → reply preview")
            },
            for: .valueChanged
        )

        failureToggle.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                hasFailed = failureToggle.isOn
                reload()
                log("\(hasFailed ? "added" : "removed")     → retry")
            },
            for: .valueChanged
        )

        host.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleFallbackTap))
        )

        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = view.bounds.width - 32

        guard width > 0, host.contentSize.width != width else { return }

        reload()
    }

    private func reload() {
        let row = row
        let width = max(1, view.bounds.width - 32)
        let node = row.node

        host.apply(node: node, layout: node.layout(in: FLContext(width: width)))
        attachGestures()
        updateRegisteredLabel()
    }

    private func attachGestures() {
        attach(UITapGestureRecognizer(target: self, action: #selector(handleAvatarTap)), to: .avatar)
        attach(UILongPressGestureRecognizer(target: self, action: #selector(handleBubbleLongPress)), to: .bubble)
        attach(
            UISwipeGestureRecognizer(target: self, action: #selector(handleBubbleSwipe)).then {
                $0.direction = .left
            },
            to: .bubble
        )
        attach(UITapGestureRecognizer(target: self, action: #selector(handleReplyTap)), to: .replyPreview)
        attach(UITapGestureRecognizer(target: self, action: #selector(handleRetryTap)), to: .retry)
    }

    private func attach(_ recognizer: UIGestureRecognizer, to part: DemoRowPart) {
        guard let partView = host.registry.view(withTag: part) else { return }

        let isAlreadyAttached = partView.gestureRecognizers?.contains {
            type(of: $0) == type(of: recognizer) && $0.name == part.title
        }

        guard isAlreadyAttached != true else { return }

        recognizer.name = part.title
        partView.addGestureRecognizer(recognizer)
    }

    private static func toggleRow(title: String, control: UISwitch) -> UIStackView {
        UIStackView(arrangedSubviews: [
            UILabel().then {
                $0.text = title
                $0.font = .systemFont(ofSize: 14)
            },
            UIView(),
            control,
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
    }

    private func updateRegisteredLabel() {
        let registered = DemoRowPart.allCases
            .filter { host.registry.contains($0) }
            .map(\.title)

        registeredLabel.text = "registered parts  \(registered.joined(separator: ", "))"
    }

    private func log(_ message: String) {
        events.insert(message, at: 0)
        events = Array(events.prefix(6))
        logLabel.text = events.joined(separator: "\n")
    }

    @objc private func handleAvatarTap() {
        log("tap        → avatar")
    }

    @objc private func handleReplyTap() {
        log("tap        → reply preview")
    }

    @objc private func handleRetryTap() {
        log("tap        → retry")
    }

    @objc private func handleBubbleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }

        log("long press → bubble")
    }

    @objc private func handleBubbleSwipe() {
        log("swipe left → bubble")
    }

    @objc private func handleFallbackTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: host)
        let hitView = host.hitTest(point, with: nil)
        let landedOnPart = DemoRowPart.allCases.contains { part in
            guard let partView = host.registry.view(withTag: part) else { return false }

            return hitView === partView || hitView?.isDescendant(of: partView) == true
        }

        guard !landedOnPart else { return }

        log("tap        → nothing, padding passed it through")
    }
}

#Preview("id + gestures") {
    FLIdentityPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
