import FrameLayout
import SwiftUI
import UIKit

struct DemoReaction: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let count: Int

    var tint: UIColor {
        let palette: [UIColor] = [.systemBlue, .systemPink, .systemTeal, .systemOrange, .systemPurple]

        return palette[abs(id.hashValue) % palette.count]
    }
}

struct DemoReactionChip: FLView {
    let reaction: DemoReaction

    var body: some FLNode {
        FLHStack(spacing: 6) {
            FLText(reaction.emoji).font(.systemFont(ofSize: 14))
            FLText("\(reaction.count)")
                .font(.systemFont(ofSize: 13, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(reaction.tint, in: .capsule)
    }
}

struct FlattenedReactions: FLView {
    let reactions: [DemoReaction]
    let showsHeader: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                FLText("header")
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.secondaryLabel)
            }

            FLForEach(reactions) { reaction in
                DemoReactionChip(reaction: reaction)
            }

            FLText("footer")
                .font(.systemFont(ofSize: 12, weight: .semibold))
                .foregroundColor(.secondaryLabel)
        }
    }
}

struct NestedReactions: FLView {
    let reactions: [DemoReaction]
    let showsHeader: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                FLText("header")
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.secondaryLabel)
            }

            FLVStack(alignment: .leading, spacing: 2) {
                FLForEach(reactions) { reaction in
                    DemoReactionChip(reaction: reaction)
                }
            }

            FLText("footer")
                .font(.systemFont(ofSize: 12, weight: .semibold))
                .foregroundColor(.secondaryLabel)
        }
    }
}

@MainActor
final class FLForEachPlaygroundViewController: UIViewController {
    private let flatHost = FLHost<FlattenedReactions>()
    private let nestedHost = FLHost<NestedReactions>()
    private let headerToggle = UISwitch().then { $0.isOn = true }
    private let readout = UILabel().then {
        $0.numberOfLines = 0
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.textColor = .secondaryLabel
    }

    private var reactions = [
        DemoReaction(id: "heart", emoji: "❤️", count: 3),
        DemoReaction(id: "laugh", emoji: "😂", count: 1),
    ]
    private var nextReaction = 0

    private let pool = [("👍", 5), ("🎉", 2), ("🔥", 9), ("👀", 4), ("🙏", 7)]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [
            caption("ForEach flattens: items are children of the outer stack, 12pt apart like its other children"),
            boxed(flatHost),
            caption("nested in its own stack: items use the inner 2pt spacing, and an empty group still costs a slot"),
            boxed(nestedHost),
            buttons(),
            toggleRow(),
            readout,
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

        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard flatHost.contentSize.width == 0, view.bounds.width > 0 else { return }

        reload()
    }

    private func reload() {
        let width = max(1, view.bounds.width - 56)
        let flat = FlattenedReactions(reactions: reactions, showsHeader: headerToggle.isOn).node
        let nested = NestedReactions(reactions: reactions, showsHeader: headerToggle.isOn).node
        let flatLayout = flat.layout(in: FLContext(width: width))
        let nestedLayout = nested.layout(in: FLContext(width: width))

        UIView.animate(withDuration: 0.25) {
            self.flatHost.apply(node: flat, layout: flatLayout)
            self.nestedHost.apply(node: nested, layout: nestedLayout)
        }

        let flattenedChildren = (headerToggle.isOn ? 1 : 0) + reactions.count + 1
        let nestedChildren = (headerToggle.isOn ? 1 : 0) + 2

        readout.text = """
            reactions   \(reactions.map(\.id).joined(separator: ", "))
            flattened   \(flattenedChildren) stack children, \(Int(flatLayout.size.height))pt tall
            nested      \(nestedChildren) stack children, \(Int(nestedLayout.size.height))pt tall
            difference  \(Int(flatLayout.size.height - nestedLayout.size.height))pt, from items taking 12pt instead of 2pt
            """
    }

    private func buttons() -> UIStackView {
        let add = UIButton(configuration: .bordered()).then { $0.setTitle("add", for: .normal) }
        let remove = UIButton(configuration: .bordered()).then { $0.setTitle("remove", for: .normal) }
        let shuffle = UIButton(configuration: .bordered()).then { $0.setTitle("reorder", for: .normal) }

        add.addAction(
            UIAction { [weak self] _ in
                guard let self else { return }

                let entry = pool[nextReaction % pool.count]
                reactions.append(DemoReaction(id: "\(entry.0)-\(nextReaction)", emoji: entry.0, count: entry.1))
                nextReaction += 1
                reload()
            },
            for: .touchUpInside
        )

        remove.addAction(
            UIAction { [weak self] _ in
                guard let self, !reactions.isEmpty else { return }

                reactions.remove(at: reactions.count / 2)
                reload()
            },
            for: .touchUpInside
        )

        shuffle.addAction(
            UIAction { [weak self] _ in
                guard let self, reactions.count > 1 else { return }

                reactions.append(reactions.removeFirst())
                reload()
            },
            for: .touchUpInside
        )

        return UIStackView(arrangedSubviews: [add, remove, shuffle, UIView()]).then {
            $0.axis = .horizontal
            $0.spacing = 8
            $0.alignment = .center
        }
    }

    private func toggleRow() -> UIStackView {
        headerToggle.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)

        return UIStackView(arrangedSubviews: [
            UILabel().then {
                $0.text = "show header"
                $0.font = .systemFont(ofSize: 14)
            },
            UIView(),
            headerToggle,
        ]).then {
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

    private func boxed(_ host: UIView) -> UIView {
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
}

#Preview("ForEach + groups") {
    FLForEachPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
