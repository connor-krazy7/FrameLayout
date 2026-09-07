import FrameLayout
import SwiftUI
import UIKit

private struct DisplayComparison: FLView {
    static var sample: String {
        """
        FrameLayout measures text off the main thread through one TextKit stack, so a display-only \
        editor and a label report the same box for the same string.
        """
    }

    static var font: UIFont { .systemFont(ofSize: 16) }

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 20) {
            FLVStack(alignment: .leading, spacing: 6) {
                FLText("FLText")
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.secondaryLabel)
                FLText(Self.sample)
                    .font(Self.font)
                    .background(.secondarySystemBackground, in: .roundedRectangle(8))
            }

            FLVStack(alignment: .leading, spacing: 6) {
                FLText("FLTextEditor, display only")
                    .font(.systemFont(ofSize: 12, weight: .semibold))
                    .foregroundColor(.secondaryLabel)
                FLTextEditor(Self.sample)
                    .font(Self.font)
                    .editable(false)
                    .selectable(false)
                    .background(.secondarySystemBackground, in: .roundedRectangle(8))
            }
        }
        .padding(20)
    }
}

/// Flow 3: the editor with editing and selection off, next to an `FLText` carrying the same string. Both
/// measure through `FLTextMeasurement`, so the status line reports one box, not two.
@MainActor
final class FLTextEditorDisplayPlaygroundViewController: UIViewController {
    private var lastLayoutWidth: CGFloat = 0

    private let host = FLHost<DisplayComparison>().then {
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
        let node = DisplayComparison().node
        let inner = lastLayoutWidth - 40
        let context = FLContext(
            width: inner,
            environment: FLEnvironment(font: DisplayComparison.font)
        )
        let text = FLText(DisplayComparison.sample).layout(in: context).size
        let editor = FLTextEditor(DisplayComparison.sample).editable(false).layout(in: context).size

        host.apply(node: node, layout: node.layout(in: FLContext(width: lastLayoutWidth)))
        statusLabel.text = """
            FLText        \(Int(text.width)) x \(Int(text.height))
            FLTextEditor  \(Int(editor.width)) x \(Int(editor.height))
            identical     \(text == editor ? "yes" : "no")
            """
    }
}

#Preview("editor → display only") {
    FLTextEditorDisplayPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
