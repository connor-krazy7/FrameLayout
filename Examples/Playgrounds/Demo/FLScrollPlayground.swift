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
    case gallery(String)
    case strip(String)
}

struct DemoGalleryPhoto: Hashable, Sendable, Identifiable {
    let id: String
    let color: UIColor
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
        .initialContentOffset(contentID: messageID)
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
        .initialContentOffset(contentID: id)
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


struct DemoPagedGallery: FLView {
    static let colors: [UIColor] = [
        .systemBlue, .systemIndigo, .systemPurple, .systemTeal,
        .systemGreen, .systemOrange, .systemPink, .systemRed,
    ]

    static func photos(from names: [String]) -> [DemoGalleryPhoto] {
        names.enumerated().map { DemoGalleryPhoto(id: $1, color: colors[$0 % colors.count]) }
    }

    let visit: String
    let photos: [DemoGalleryPhoto]
    let opensAt: String
    let pageSize: CGSize

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack {
                FLForEach(photos) { photo in
                    FLText(photo.id)
                        .font(.systemFont(ofSize: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: pageSize.width, height: pageSize.height)
                        .background(photo.color, in: .roundedRectangle(12))
                        .tag(photo.id)
                }
            }
        }
        .paging()
        .bounces(false)
        .scrollIndicators(.hidden)
        .scrollAnchor(.element(opensAt), contentID: visit)
        .frame(width: pageSize.width, height: pageSize.height)
        .tag(DemoScrollPart.gallery(visit))
    }
}

struct DemoThumbnailStrip: FLView {
    let visit: String
    let photos: [DemoGalleryPhoto]
    let opensAt: String
    let alignment: FLAlignment
    let thumbnail: CGFloat

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHStack(spacing: 8) {
                FLForEach(photos) { photo in
                    FLText(photo.id.suffix(2).description)
                        .font(.systemFont(ofSize: 11, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: thumbnail, height: thumbnail)
                        .background(photo.color, in: .roundedRectangle(8))
                        .tag(photo.id)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollAnchor(.element(opensAt, alignment: alignment), contentID: visit)
        .tag(DemoScrollPart.strip(visit))
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
    @State private var visitIndex = 0
    @State private var opensAtIndex = 3
    @State private var alignmentIndex = 0
    @State private var hasPrependedPhoto = false

    private static let albumNames = (0..<8).map { "photo-\($0)" }

    private static let alignments: [(name: String, value: FLAlignment)] = [
        ("topLeading", .topLeading),
        ("center", .center),
        ("trailing", .trailing),
    ]

    private var messageID: String { "message-\(messageIndex)" }
    private var visit: String { "visit-\(visitIndex)" }
    private var opensAt: String { Self.albumNames[opensAtIndex] }
    private var alignment: FLAlignment { Self.alignments[alignmentIndex].value }

    private var photos: [DemoGalleryPhoto] {
        let names = hasPrependedPhoto ? ["photo-new"] + Self.albumNames : Self.albumNames

        return DemoPagedGallery.photos(from: names)
    }

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

                ScrollCase(
                    title: "paged gallery, one photo per page, opened at \(opensAt)",
                    detail: "page width equals the viewport, so every alignment resolves the same offset",
                    content: DemoPagedGallery(
                        visit: visit,
                        photos: photos,
                        opensAt: opensAt,
                        pageSize: CGSize(width: 320, height: 150)
                    )
                )

                ScrollCase(
                    title: "thumbnail strip, opened at \(opensAt) aligned \(Self.alignments[alignmentIndex].name)",
                    detail: "a thumbnail is narrower than the viewport, so the alignment has slack to place it in",
                    content: DemoThumbnailStrip(
                        visit: visit,
                        photos: photos,
                        opensAt: opensAt,
                        alignment: alignment,
                        thumbnail: 72
                    )
                )

                controls

                anchorControls
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

    private var anchorControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("opens at: \(opensAt)", value: $opensAtIndex, in: 0...(Self.albumNames.count - 1))
                .font(.system(size: 12))

            Picker("alignment", selection: $alignmentIndex) {
                ForEach(Array(Self.alignments.enumerated()), id: \.offset) { index, alignment in
                    Text(alignment.name).tag(index)
                }
            }
            .pickerStyle(.segmented)

            Toggle("prepend a photo before the album", isOn: $hasPrependedPhoto)
                .font(.system(size: 12))

            Button("re-open the album (applies the anchor)") {
                visitIndex += 1
            }
            .font(.system(size: 12))

            Text("an anchor is applied once per content, so the two controls above take effect on the next re-open — the same way a gallery opens where it was left rather than fighting a drag. Prepending shifts every index by one and the anchor still finds its photo, which is what an id buys over a stored offset.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("scroll: regions inside a tree") {
    ScrollPlayground()
}
