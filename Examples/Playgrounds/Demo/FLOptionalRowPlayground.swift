import FrameLayout
import SwiftUI
import UIKit

/// A message row where four parts are conditional and each carries its modifiers at the **use site** —
/// the shape that used to leave a gap for a part that is not there. Toggle any of them and the row
/// re-lays out against the SwiftUI column built the same way, so a leftover inset or spacing gap shows up
/// as a height that no longer matches.
struct MessageRowModel: Hashable, Sendable {
    var showsBadge = true
    var showsAttachment = true
    var showsError = true
    var showsFootnote = true

    static var body: String {
        "Reserved the box from the model, so the row settles before the attachment finishes loading."
    }
}

// MARK: - The row, as a node

struct FLMessageRow: FLView {
    let model: MessageRowModel

    private var inset: CGFloat { 10 }

    @FLNodeBuilder private var badge: some FLNode {
        if model.showsBadge {
            FLText("NEW").font(.systemFont(ofSize: 11, weight: .bold)).foregroundColor(.white)
        }
    }

    @FLNodeBuilder private var attachment: some FLNode {
        if model.showsAttachment {
            FLColor(.systemTeal).frame(width: 160, height: 90)
        }
    }

    @FLNodeBuilder private var errorText: some FLNode {
        if model.showsError {
            FLText("Could not send").font(.systemFont(ofSize: 13)).foregroundColor(.systemRed)
        }
    }

    @FLNodeBuilder private var footnote: some FLNode {
        if model.showsFootnote {
            FLText("edited").font(.systemFont(ofSize: 11)).foregroundColor(.secondaryLabel)
        }
    }

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 10) {
            FLColor(.systemGray3).frame(width: 40, height: 40).cornerRadius(20)

            FLVStack(alignment: .leading, spacing: 4) {
                FLHStack(alignment: .center, spacing: 6) {
                    FLText("Ada").font(.systemFont(ofSize: 15, weight: .semibold)).foregroundColor(.label)
                    badge
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.systemIndigo, in: .capsule)
                }

                FLText(MessageRowModel.body).font(.systemFont(ofSize: 15)).foregroundColor(.label)

                attachment
                    .cornerRadius(10, curve: .continuous)
                    .padding(.top, 4)

                errorText
                    .padding(8)
                    .background(UIColor.systemRed.withAlphaComponent(0.12), in: .roundedRectangle(8))
                    .padding(.top, 4)

                footnote
                    .padding(.top, 2)
            }
        }
        .padding(inset)
    }
}

// MARK: - The same row, in SwiftUI

struct MessageRowView: View {
    let model: MessageRowModel

    @ViewBuilder private var badge: some View {
        if model.showsBadge {
            Text("NEW").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var attachment: some View {
        if model.showsAttachment {
            Color.teal.frame(width: 160, height: 90)
        }
    }

    @ViewBuilder private var errorText: some View {
        if model.showsError {
            Text("Could not send").font(.system(size: 13)).foregroundStyle(Color(uiColor: .systemRed))
        }
    }

    @ViewBuilder private var footnote: some View {
        if model.showsFootnote {
            Text("edited").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Color(uiColor: .systemGray3).frame(width: 40, height: 40).clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text("Ada").font(.system(size: 15, weight: .semibold))
                    badge
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo, in: Capsule())
                }

                Text(MessageRowModel.body).font(.system(size: 15))

                attachment
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 4)

                errorText
                    .padding(8)
                    .background(Color(uiColor: .systemRed.withAlphaComponent(0.12)), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 4)

                footnote
                    .padding(.top, 2)
            }
        }
        .padding(10)
    }
}

// MARK: - Playground

private struct OptionalRowPlayground: View {
    @State private var model = MessageRowModel()

    private let width: CGFloat = 320

    private var flHeight: CGFloat {
        FLMessageRow(model: model).node.layout(in: FLContext(width: width)).size.height
    }

    private var swiftUIHeight: CGFloat {
        UIHostingController(rootView: MessageRowView(model: model).frame(width: width))
            .sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity)).height
    }

    private var agrees: Bool { abs(flHeight - swiftUIHeight) <= 1 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle("badge", isOn: $model.showsBadge)
                Toggle("attachment", isOn: $model.showsAttachment)
                Toggle("error", isOn: $model.showsError)
                Toggle("footnote", isOn: $model.showsFootnote)

                Text(agrees ? "heights agree" : "heights differ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(agrees ? Color.secondary : Color.orange)

                labelled("SwiftUI — height \(rounded(swiftUIHeight))") {
                    MessageRowView(model: model).frame(width: width, alignment: .leading)
                }
                labelled("FrameLayout — height \(rounded(flHeight))") {
                    FLNodePreview(
                        node: FLMessageRow(model: model).node,
                        layoutContext: FLContext(width: width)
                    )
                }
            }
            .font(.subheadline)
            .padding(20)
        }
    }

    private func rounded(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func labelled(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
            content()
                .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(.tertiary))
        }
    }
}

#Preview("optional row") {
    OptionalRowPlayground()
}
