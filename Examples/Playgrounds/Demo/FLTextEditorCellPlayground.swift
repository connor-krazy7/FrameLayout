import FrameLayout
import SwiftUI
import UIKit

private struct DraftItem: Hashable, Sendable {
    let id: Int
    let subject: String
    var draft: String
}

private enum DraftPart: Hashable, Sendable {
    case input
}

private struct DraftRow: FLView {
    let item: DraftItem

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLText(item.subject)
                .font(.systemFont(ofSize: 15, weight: .semibold))

            FLTextEditor(item.draft, placeholder: "Write a reply")
                .font(.systemFont(ofSize: 15))
                .textContainerInset(.all(10))
                .contentID(item.id)
                .tag(DraftPart.input)
                .frame(minHeight: 64)
                .background(.secondarySystemBackground, in: .roundedRectangle(10), curve: .continuous)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private final class DraftCell: UITableViewCell {
    static let identifier = "DraftCell"

    private let host = FLHost<DraftRow>().then {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        contentView.addSubview(host)

        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: contentView.topAnchor),
            host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        host.registry.bindView(withTag: DraftPart.input, as: FLTextEditorInput.self) { [weak self] input in
            input.delegate = self?.delegateTarget
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private weak var delegateTarget: UITextViewDelegate?

    func configure(item: DraftItem, width: CGFloat, delegate: UITextViewDelegate) {
        let node = DraftRow(item: item).node

        delegateTarget = delegate
        host.apply(node: node, layout: node.layout(in: FLContext(width: width)))
    }
}

/// Flow 2: an editor inside a reused cell, prefilled or not. `contentID(_:)` is what makes recycling
/// correct — scrolling a row away and back shows that row's draft rather than whatever the previous
/// occupant left in the view.
@MainActor
final class FLTextEditorCellPlaygroundViewController: UIViewController {
    private var items: [DraftItem] = (0..<12).map {
        DraftItem(
            id: $0,
            subject: "Thread \($0 + 1)",
            draft: $0.isMultiple(of: 3) ? "A draft that was already saved for thread \($0 + 1)." : ""
        )
    }

    private let tableView = UITableView().then {
        $0.rowHeight = UITableView.automaticDimension
        $0.estimatedRowHeight = 120
        $0.separatorStyle = .none
        $0.keyboardDismissMode = .interactive
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.register(DraftCell.self, forCellReuseIdentifier: DraftCell.identifier)
        view.addSubview(tableView)
    }
}

// MARK: - UITableViewDataSource

extension FLTextEditorCellPlaygroundViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DraftCell.identifier, for: indexPath)

        (cell as? DraftCell)?.configure(
            item: items[indexPath.row],
            width: tableView.bounds.width,
            delegate: self
        )

        return cell
    }
}

// MARK: - UITextViewDelegate

extension FLTextEditorCellPlaygroundViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        guard let indexPath = indexPath(for: textView) else { return }

        items[indexPath.row].draft = textView.text

        // The node is rebuilt so the row re-measures; the editor keeps the text it holds because the
        // item's `contentID` has not changed.
        (tableView.cellForRow(at: indexPath) as? DraftCell)?.configure(
            item: items[indexPath.row],
            width: tableView.bounds.width,
            delegate: self
        )
        tableView.performBatchUpdates(nil)
    }

    private func indexPath(for textView: UITextView) -> IndexPath? {
        var candidate: UIView? = textView

        while let view = candidate, !(view is DraftCell) {
            candidate = view.superview
        }

        return (candidate as? DraftCell).flatMap(tableView.indexPath(for:))
    }
}

#Preview("editor → reused cell") {
    FLTextEditorCellPlaygroundViewController.asViewRepresentable()
        .ignoresSafeArea()
}
