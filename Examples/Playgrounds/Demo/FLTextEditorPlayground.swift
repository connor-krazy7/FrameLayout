import FrameLayout
import SwiftUI
import UIKit

private enum EditorPart: Hashable, Sendable {
    case input
}

private struct EditorCard: FLView {
    let draft: String

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 10) {
            FLText("Compose")
                .font(.systemFont(ofSize: 13, weight: .semibold))
                .foregroundColor(.secondaryLabel)

            FLTextEditor(draft, placeholder: "Say something")
                .font(.systemFont(ofSize: 17))
                .textContainerInset(.all(12))
                .returnKeyType(.default)
                .tag(EditorPart.input)
                .frame(minHeight: 120)
                .background(.secondarySystemBackground, in: .roundedRectangle(12), curve: .continuous)

            FLText("The card grows because the delegate rebuilds the node, not because the editor resizes itself.")
                .font(.systemFont(ofSize: 12))
                .foregroundColor(.tertiaryLabel)
        }
        .padding(20)
    }
}

/// Flow 1: an editable editor on a static screen. Typing does not resize anything on its own — the
/// delegate hands the text to the model, a new node is measured, and the card takes the new frame while
/// the editor keeps the text it already holds.
@MainActor
final class FLTextEditorPlaygroundViewController: UIViewController {
    private var draft = "Prefilled, and yours to edit. Add a few lines and watch the card follow."
    private var lastLayoutWidth: CGFloat = 0
    private var updateCount = 0

    private let host = FLHost<EditorCard>().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let statusLabel = UILabel().then {
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.textColor = .secondaryLabel
        $0.numberOfLines = 0
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        view.addSubview(host)
        view.addSubview(statusLabel)

        // Declared before the first apply, so it reaches the editor as soon as it registers itself.
        host.registry.bindView(withTag: EditorPart.input, as: FLTextEditorInput.self) { [weak self] input in
            input.delegate = self
        }

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: host.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard view.bounds.width > 0, view.bounds.width != lastLayoutWidth else { return }

        lastLayoutWidth = view.bounds.width
        reload()
    }

    private func reload() {
        let node = EditorCard(draft: draft).node
        let context = FLContext(
            width: lastLayoutWidth,
            contentSizeCategory: traitCollection.preferredContentSizeCategory.rawValue
        )
        let layout = node.layout(in: context)

        updateCount += 1
        host.apply(node: node, layout: layout)
        statusLabel.text = """
            card    \(Int(layout.size.width)) x \(Int(layout.size.height))
            draft   \(draft.count) characters
            applies \(updateCount)
            """
    }
}

extension FLTextEditorPlaygroundViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        draft = textView.text

        UIView.animate(withDuration: 0.2) {
            self.reload()
            self.view.layoutIfNeeded()
        }
    }
}

#Preview("editor → static screen") {
    FLTextEditorPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
