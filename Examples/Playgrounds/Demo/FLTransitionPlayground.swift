import FrameLayout
import SwiftUI
import UIKit

enum TransitionDemoPart: Hashable, Sendable {
    case header
    case retry
    case footer
}

struct CollapsingDemoRow: FLView {
    let showsRetry: Bool
    let animation: FLAnimation

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLText("Delivered")
                .font(.systemFont(ofSize: 15))
                .foregroundColor(.white)
                .padding(10)
                .background(.systemBlue, in: .roundedRectangle(12))
                .tag(TransitionDemoPart.header)

            FLText("Tap to retry")
                .font(.systemFont(ofSize: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: showsRetry ? 26 : 0)
                .background(.systemRed, in: .roundedRectangle(8))
                .clipped()
                .opacity(showsRetry ? 1 : 0)
                .tag(TransitionDemoPart.retry)

            FLText("09:41")
                .font(.systemFont(ofSize: 11))
                .foregroundColor(.secondaryLabel)
                .tag(TransitionDemoPart.footer)
        }
        .animation(animation, value: showsRetry)
    }
}

struct ConditionalDemoRow: FLView {
    let showsRetry: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLText("Delivered")
                .font(.systemFont(ofSize: 15))
                .foregroundColor(.white)
                .padding(10)
                .background(.systemBlue, in: .roundedRectangle(12))
                .tag(TransitionDemoPart.header)

            if showsRetry {
                FLText("Tap to retry")
                    .font(.systemFont(ofSize: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(.systemRed, in: .roundedRectangle(8))
                    .tag(TransitionDemoPart.retry)
            }

            FLText("09:41")
                .font(.systemFont(ofSize: 11))
                .foregroundColor(.secondaryLabel)
                .tag(TransitionDemoPart.footer)
        }
    }
}

struct DemoChipItem: FLView {
    let title: String

    var body: some FLNode {
        FLText(title)
            .font(.systemFont(ofSize: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.systemIndigo, in: .capsule)
    }
}

@MainActor
final class FLTransitionPlaygroundViewController: UIViewController {
    private typealias ChipList = FLAnimatedList<String, FLComposed<DemoChipItem>>

    private let collapsingHost = FLHost<CollapsingDemoRow>()
    private let conditionalHost = FLHost<ConditionalDemoRow>()
    private let listHost = FLHostView<ChipList>()
    private let addButton = UIButton(configuration: .bordered()).then { $0.setTitle("add", for: .normal) }
    private let removeButton = UIButton(configuration: .bordered()).then { $0.setTitle("remove middle", for: .normal) }
    private let timingControl = UISegmentedControl(items: ["linear", "ease", "spring"]).then { $0.selectedSegmentIndex = 1 }
    private let durationControl = UISegmentedControl(items: ["0.25s", "0.6s", "1.2s"]).then { $0.selectedSegmentIndex = 1 }
    private let retryToggle = UISwitch()
    private let measurementsLabel = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.textColor = .secondaryLabel
    }

    private var showsRetry = false
    private var chipTitles = ["one", "two", "three"]
    private var nextChip = 4

    private var duration: TimeInterval {
        [0.25, 0.6, 1.2][durationControl.selectedSegmentIndex]
    }

    private var animation: FLAnimation {
        switch timingControl.selectedSegmentIndex {
        case 0: .linear(duration)
        case 2: .spring(duration, damping: 0.6)
        default: .easeInOut(duration)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [
            caption("collapse + fade — the node stays, height and opacity animate"),
            box(collapsingHost),
            caption("if — the node leaves; it grows in from the corner and vanishes on the way out"),
            box(conditionalHost),
            caption("a custom FLNode that animates its own arrivals and departures"),
            box(listHost),
            buttons(),
            row("show retry", retryToggle),
            timingControl,
            durationControl,
            measurementsLabel,
        ]).then {
            $0.axis = .vertical
            $0.spacing = 12
            $0.alignment = .fill
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        let reapply = UIAction { [weak self] _ in
            guard let self else { return }

            showsRetry = retryToggle.isOn
            reload()
        }

        retryToggle.addAction(reapply, for: .valueChanged)

        addButton.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                chipTitles.append("item \(nextChip)")
                nextChip += 1
                reload()
            },
            for: .touchUpInside
        )

        removeButton.addAction(
            UIAction { [weak self] _ in
                guard let self, !chipTitles.isEmpty else { return }

                chipTitles.remove(at: chipTitles.count / 2)
                reload()
            },
            for: .touchUpInside
        )
        timingControl.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)
        durationControl.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)

        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard collapsingHost.contentSize.width == 0, view.bounds.width > 0 else { return }

        reload()
    }

    private func reload() {
        let width = max(1, view.bounds.width - 32)
        let collapsing = CollapsingDemoRow(showsRetry: showsRetry, animation: animation).node
        let conditional = ConditionalDemoRow(showsRetry: showsRetry).node
        let collapsingLayout = collapsing.layout(in: FLContext(width: width))
        let conditionalLayout = conditional.layout(in: FLContext(width: width))

        collapsingHost.apply(node: collapsing, layout: collapsingLayout)

        UIView.animate(withDuration: duration) {
            self.conditionalHost.apply(node: conditional, layout: conditionalLayout)
        }

        let chips = ChipList(
            items: chipTitles.map { FLListItem(id: $0, node: DemoChipItem(title: $0).node) },
            spacing: 8,
            animation: animation
        )
        let chipsLayout = chips.layout(in: FLContext(width: width))

        listHost.apply(node: chips, layout: chipsLayout)
        removeButton.isEnabled = !chipTitles.isEmpty

        measurementsLabel.text = """
            collapse + fade  \(Int(collapsingLayout.size.height))pt tall, retry view stays in the tree
            if               \(Int(conditionalLayout.size.height))pt tall, retry view is detached when hidden
            difference       \(Int(collapsingLayout.size.height - conditionalLayout.size.height))pt of spacing the collapsed part still holds
            """
    }

    private func buttons() -> UIStackView {
        UIStackView(arrangedSubviews: [addButton, removeButton, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
    }

    private func caption(_ text: String) -> UILabel {
        UILabel().then {
            $0.text = text
            $0.numberOfLines = 0
            $0.font = .systemFont(ofSize: 12, weight: .medium)
            $0.textColor = .label
        }
    }

    private func box(_ host: UIView) -> UIView {
        UIView().then {
            $0.backgroundColor = .secondarySystemBackground
            $0.layer.cornerRadius = 10
            $0.addSubview(host)
            host.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                host.topAnchor.constraint(equalTo: $0.topAnchor, constant: 12),
                host.leadingAnchor.constraint(equalTo: $0.leadingAnchor, constant: 12),
                $0.trailingAnchor.constraint(greaterThanOrEqualTo: host.trailingAnchor, constant: 12),
                $0.bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: 12),
            ])
        }
    }

    private func row(_ title: String, _ control: UIView) -> UIStackView {
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
}

#Preview("transitions") {
    FLTransitionPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
