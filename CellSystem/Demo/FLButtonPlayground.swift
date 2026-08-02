import SwiftUI
import UIKit

enum ButtonDemoPart: Hashable, Sendable, CaseIterable {
    case send
    case cancel
    case more
    case card
    case retry

    var title: String {
        switch self {
        case .send: "send"
        case .cancel: "cancel"
        case .more: "more"
        case .card: "card"
        case .retry: "retry"
        }
    }
}

struct ButtonDemoToolbar: FLView {
    let isDisabled: Bool
    let showsRetry: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 12) {
            FLHStack(spacing: 8) {
                FLButton(tag: ButtonDemoPart.send, style: .scaling(0.94, opacity: 0.7)) {
                    FLText("Send")
                        .font(.systemFont(ofSize: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.systemBlue, in: .capsule)
                }
                .accessibilityLabel("Send message")

                FLButton(tag: ButtonDemoPart.cancel) {
                    FLText("Cancel")
                        .font(.systemFont(ofSize: 15))
                        .foregroundColor(.systemBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                }
                .accessibilityLabel("Cancel")

                FLButton(tag: ButtonDemoPart.more, style: .scaling(0.88)) {
                    FLImage(UIImage(systemName: "ellipsis"))
                        .tint(.label)
                        .frame(width: 36, height: 36)
                        .background(.secondarySystemFill, in: .capsule)
                }
                .accessibilityLabel("More actions")

                FLSpacer()
            }

            FLButton(tag: ButtonDemoPart.card, style: .scaling(0.98)) {
                FLHStack(spacing: 10) {
                    FLColor(.systemTeal)
                        .frame(width: 40, height: 40)
                        .clipShape(.capsule)

                    FLVStack(alignment: .leading, spacing: 2) {
                        FLText("Ann Petrova")
                            .font(.systemFont(ofSize: 15, weight: .semibold))
                            .foregroundColor(.label)
                        FLText("a whole row can be the button")
                            .font(.systemFont(ofSize: 13))
                            .foregroundColor(.secondaryLabel)
                    }

                    FLSpacer()
                }
                .padding(12)
                .background(.secondarySystemBackground, in: .roundedRectangle(14))
            }
            .accessibilityLabel("Open profile")

            if showsRetry {
                FLButton(tag: ButtonDemoPart.retry, style: .scaling(0.94, opacity: 0.7)) {
                    FLText("Retry")
                        .font(.systemFont(ofSize: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.systemRed, in: .capsule)
                }
                .accessibilityLabel("Retry sending")
            }
        }
        .disabled(isDisabled)
    }
}

@MainActor
final class FLButtonPlaygroundViewController: UIViewController {
    private let scrollView = UIScrollView().then { $0.translatesAutoresizingMaskIntoConstraints = false }
    private let host = FLHost<ButtonDemoToolbar>()
    private let delaysToggle = UISwitch().then { $0.isOn = true }
    private let disabledToggle = UISwitch()
    private let retryToggle = UISwitch()
    private let log = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        $0.textColor = .secondaryLabel
    }

    private var events: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let filler = UILabel().then {
            $0.numberOfLines = 0
            $0.font = .systemFont(ofSize: 13)
            $0.textColor = .tertiaryLabel
            $0.text = Array(repeating: "drag from a button to scroll — a UIControl does not block the pan", count: 12)
                .joined(separator: "\n\n")
        }

        let scrolled = UIStackView(arrangedSubviews: [host, filler]).then {
            $0.axis = .vertical
            $0.spacing = 20
            $0.alignment = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let controls = UIStackView(arrangedSubviews: [
            toggleRow("scroll view delays content touches", delaysToggle),
            toggleRow("disable the whole toolbar", disabledToggle),
            toggleRow("show the retry button", retryToggle),
            log,
        ]).then {
            $0.axis = .vertical
            $0.spacing = 8
            $0.alignment = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        scrollView.addSubview(scrolled)
        view.addSubview(scrollView)
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -12),

            scrolled.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            scrolled.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            scrolled.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            scrolled.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            controls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        delaysToggle.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                scrollView.delaysContentTouches = delaysToggle.isOn
                record("delaysContentTouches = \(delaysToggle.isOn)")
            },
            for: .valueChanged
        )

        disabledToggle.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)

        retryToggle.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                reload()
                record("retry button \(retryToggle.isOn ? "appeared" : "went away")")
            },
            for: .valueChanged
        )

        bindActions()
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard host.contentSize.width == 0, view.bounds.width > 0 else { return }

        reload()
    }

    private func reload() {
        let width = max(1, view.bounds.width - 32)
        let node = ButtonDemoToolbar(isDisabled: disabledToggle.isOn, showsRetry: retryToggle.isOn).node

        host.apply(node: node, layout: node.layout(in: FLContext(width: width)))
        record("toolbar \(disabledToggle.isOn ? "disabled" : "enabled")")
    }

    private func bindActions() {
        for part in ButtonDemoPart.allCases {
            host.registry.bindAction(withTag: part) { [weak self] _ in
                self?.record("tapped \(part.title)")
            }
        }
    }

    private func record(_ message: String) {
        events.insert(message, at: 0)
        events = Array(events.prefix(5))
        log.text = events.joined(separator: "\n")
    }

    private func toggleRow(_ title: String, _ control: UISwitch) -> UIStackView {
        UIStackView(arrangedSubviews: [
            UILabel().then {
                $0.text = title
                $0.font = .systemFont(ofSize: 14)
                $0.numberOfLines = 0
            },
            UIView(),
            control,
        ]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
    }
}

#Preview("buttons") {
    FLButtonPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
