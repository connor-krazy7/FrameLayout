import FrameLayout
import SwiftUI
import UIKit

struct DemoScrollChip: Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let color: UIColor
}

enum DemoScrollPart: Hashable, Sendable {
    case chips(String)
    case body(String)
}

struct DemoChipRow: FLView {
    static var chips: [DemoScrollChip] {
        [
            DemoScrollChip(id: "all", title: "All", color: .systemBlue),
            DemoScrollChip(id: "unread", title: "Unread", color: .systemIndigo),
            DemoScrollChip(id: "mentions", title: "Mentions", color: .systemPurple),
            DemoScrollChip(id: "files", title: "Files", color: .systemTeal),
            DemoScrollChip(id: "links", title: "Links", color: .systemGreen),
            DemoScrollChip(id: "pinned", title: "Pinned", color: .systemOrange),
            DemoScrollChip(id: "archived", title: "Archived", color: .systemPink),
        ]
    }

    let messageID: String
    let showsIndicators: Bool

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack(spacing: 6) {
                FLForEach(Self.chips) { chip in
                    FLButton(tag: chip.id) {
                        FLText(chip.title)
                            .font(.systemFont(ofSize: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(FLEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            .background(chip.color, in: .roundedRectangle(12))
                    }
                }
            }
        }
        .initialContentOffset(forContent: messageID)
        .scrollIndicators(showsIndicators ? .automatic : .hidden)
        .contentInsets(FLEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        .tag(DemoScrollPart.chips(messageID))
    }
}

struct DemoScrollableBody: FLView {
    let id: String
    let paragraphs: Int
    let maximumHeight: CGFloat

    var body: some FLNode {
        FLScroll {
            FLVStack(alignment: .leading, spacing: 8) {
                FLForEach(Array(0..<paragraphs), id: \.self) { index in
                    FLText("Paragraph \(index + 1). A scroll region measures its content unbounded along the axis, so this keeps its natural height while the region takes only what it was offered.")
                        .font(.systemFont(ofSize: 12))
                }
            }
        }
        .initialContentOffset(forContent: id)
        .contentInsets(FLEdgeInsets.all(10))
        .frame(maxHeight: maximumHeight)
        .background(.secondarySystemBackground, in: .roundedRectangle(12))
        .tag(DemoScrollPart.body(id))
    }
}

struct DemoUnboundedBody: FLView {
    let paragraphs: Int

    var body: some FLNode {
        FLScroll {
            FLVStack(alignment: .leading, spacing: 8) {
                FLForEach(Array(0..<paragraphs), id: \.self) { index in
                    FLText("Unbounded \(index + 1). With no extent offered along the axis, the region collapses to its content and never scrolls — the same as a SwiftUI ScrollView in a self-sizing cell.")
                        .font(.systemFont(ofSize: 12))
                }
            }
        }
        .background(.tertiarySystemFill, in: .roundedRectangle(12))
    }
}

private struct ScrollCase<Content: FLView>: View {
    let title: String
    let detail: String
    let content: Content
    var width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            Text(detail)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            FLNodePreview(node: content.node, layoutContext: FLContext(width: width))
                .border(.blue.opacity(0.4))
        }
    }
}

private struct ScrollPlayground: View {
    @State private var messageIndex = 0
    @State private var showsIndicators = false
    @State private var paragraphs = 6

    private var messageID: String { "message-\(messageIndex)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("a scroll region takes the extent it is offered and measures its content unbounded along the axis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ScrollCase(
                    title: "horizontal chip row, bounded by its content height",
                    detail: measured(DemoChipRow(messageID: messageID, showsIndicators: showsIndicators).node),
                    content: DemoChipRow(messageID: messageID, showsIndicators: showsIndicators)
                )

                ScrollCase(
                    title: "vertical body capped with frame(maxHeight: 160) — scrolls",
                    detail: measured(DemoScrollableBody(id: messageID, paragraphs: paragraphs, maximumHeight: 160).node),
                    content: DemoScrollableBody(id: messageID, paragraphs: paragraphs, maximumHeight: 160)
                )

                ScrollCase(
                    title: "the same content with nothing offered — collapses, never scrolls",
                    detail: measured(DemoUnboundedBody(paragraphs: min(paragraphs, 2)).node),
                    content: DemoUnboundedBody(paragraphs: min(paragraphs, 2))
                )

                controls
            }
            .padding(20)
        }
    }

    private func measured(_ node: some FLNode) -> String {
        let size = node.layout(in: FLContext(width: 320)).size

        return "reserves \(Int(size.width)) × \(Int(size.height)) in a 320pt box"
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("paragraphs: \(paragraphs)", value: $paragraphs, in: 1...12)
                .font(.system(size: 12))

            Toggle("show indicators", isOn: $showsIndicators)
                .font(.system(size: 12))

            Button("switch message (resets both offsets)") {
                messageIndex += 1
            }
            .font(.system(size: 12))

            Text("scroll a region, then switch message: the reset token puts it back to the start, while changing the paragraph count leaves the offset alone")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("scroll: regions inside a tree") {
    ScrollPlayground()
}
