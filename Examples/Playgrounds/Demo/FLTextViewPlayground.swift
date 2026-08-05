import FrameLayout
import SwiftUI
import UIKit

struct PlaygroundCard: FLView {
    let text: String

    private var isEmpty: Bool { text.isEmpty }

    private var lines: Int {
        isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 10) {
            FLText(isEmpty ? "Type above and this card adapts…" : text)
                .font(.systemFont(ofSize: 17))
                .foregroundColor(isEmpty ? .tertiaryLabel : .label)

            FLColor(.separator).frame(height: 1)

            FLHStack(spacing: 8) {
                FLText("characters")
                    .font(.systemFont(ofSize: 13))
                    .foregroundColor(.secondaryLabel)
                FLSpacer()
                FLText("\(text.count)")
                    .font(.systemFont(ofSize: 13, weight: .semibold))
                    .foregroundColor(.label)
            }

            FLHStack(spacing: 8) {
                FLText("paragraphs")
                    .font(.systemFont(ofSize: 13))
                    .foregroundColor(.secondaryLabel)
                FLSpacer()
                FLText("\(lines)")
                    .font(.systemFont(ofSize: 13, weight: .semibold))
                    .foregroundColor(.label)
            }
        }
        .padding(16)
        .background(.secondarySystemBackground, in: .roundedRectangle(16), curve: .continuous)
    }
}

@MainActor
final class FLTextViewPlaygroundViewController: UIViewController {
    private enum Layout {
        static var inset: CGFloat { 20 }
        static var spacing: CGFloat { 16 }
        static var minimumInputHeight: CGFloat { 88 }
        static var inputFont: UIFont { .systemFont(ofSize: 16) }
        static var inputInset: UIEdgeInsets { UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6) }
    }

    private let scrollView = UIScrollView().then {
        $0.keyboardDismissMode = .interactive
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    // `isScrollEnabled = false` is what makes a UITextView self-sizing: its intrinsicContentSize
    // tracks the text, so Auto Layout grows it with no measurement here.
    private let textView = UITextView().then {
        $0.font = Layout.inputFont
        $0.isScrollEnabled = false
        $0.textContainerInset = Layout.inputInset
        $0.layer.borderColor = UIColor.separator.cgColor
        $0.layer.borderWidth = 1
        $0.layer.cornerRadius = 10
        $0.layer.cornerCurve = .continuous
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let placeholderLabel = UILabel().then {
        $0.text = "Type here — multiple lines welcome"
        $0.font = Layout.inputFont
        $0.textColor = .tertiaryLabel
        $0.numberOfLines = 0
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let statusLabel = UILabel().then {
        $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        $0.textColor = .secondaryLabel
        $0.numberOfLines = 0
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let host = FLHost<PlaygroundCard>().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private var layoutTask: Task<Void, Never>?
    private var lastLayoutWidth: CGFloat = 0
    private var updateCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        textView.delegate = self

        activateConstraints()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // The one number the controller still needs: what width to propose to FrameLayout. Every
        // other position and size is a constraint.
        let available = textView.bounds.width
        guard available > 0, available != lastLayoutWidth else { return }

        lastLayoutWidth = available
        reload(animated: false)
    }

    private func activateConstraints() {
        view.addSubview(scrollView)
        scrollView.addSubview(textView)
        scrollView.addSubview(host)
        scrollView.addSubview(statusLabel)
        textView.addSubview(placeholderLabel)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide
        let padding = textView.textContainer.lineFragmentPadding

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            textView.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: Layout.spacing),
            textView.leadingAnchor.constraint(equalTo: frameGuide.leadingAnchor, constant: Layout.inset),
            textView.trailingAnchor.constraint(equalTo: frameGuide.trailingAnchor, constant: -Layout.inset),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumInputHeight),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: Layout.inputInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: Layout.inputInset.left + padding),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -Layout.inputInset.right),

            // The host carries no size constraints: its intrinsicContentSize is the precomputed
            // layout, so Auto Layout reads the FrameLayout result rather than being told it.
            host.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: Layout.spacing),
            host.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            host.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor),

            statusLabel.topAnchor.constraint(equalTo: host.bottomAnchor, constant: Layout.spacing),
            statusLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -Layout.spacing)
        ])
    }

    private func reload(animated: Bool) {
        guard lastLayoutWidth > 0 else { return }

        let node = PlaygroundCard(text: textView.text.orEmpty).node
        let context = FLContext(
            width: lastLayoutWidth,
            layoutDirection: view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight,
            contentSizeCategory: traitCollection.preferredContentSizeCategory.rawValue
        )

        // Measurement runs off the main thread, so a fast typist can outrun it. Cancelling the
        // previous task is what stops a stale layout landing after a newer one.
        layoutTask?.cancel()
        layoutTask = Task { [weak self] in
            let layout = await FLLayoutComputer.layout(node, in: context)

            guard let self, !Task.isCancelled else { return }

            self.apply(node: node, layout: layout, animated: animated)
        }
    }

    private func apply(
        node: FLComposed<PlaygroundCard>,
        layout: FLComposed<PlaygroundCard>.Layout,
        animated: Bool
    ) {
        updateCount += 1

        // `apply` invalidates the host's intrinsic content size, so the only thing left to do is let
        // Auto Layout settle — inside an animation block when the change should be animated.
        host.apply(node: node, layout: layout)
        statusLabel.text = """
            input   \(Int(textView.bounds.height))pt tall, intrinsic sizing
            card    \(Int(layout.size.width)) x \(Int(layout.size.height))
            updates \(updateCount)
            """

        guard animated else { return view.layoutIfNeeded() }

        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            self.view.layoutIfNeeded()
        }
    }
}

extension FLTextViewPlaygroundViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.orEmpty.isEmpty
        reload(animated: true)
    }
}

#Preview("text view → FLView") {
    FLTextViewPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
