import FrameLayout
import SwiftUI
import UIKit

struct DemoGridPhoto: Hashable, Sendable, Identifiable {
    let id: Int
    let color: UIColor
}

enum DemoGridPart: Hashable, Sendable {
    case photo(Int)
    case emoji(String)
}

struct DemoPhotoGrid: FLView {
    static func photos(_ count: Int) -> [DemoGridPhoto] {
        let palette: [UIColor] = [.systemBlue, .systemIndigo, .systemTeal, .systemGreen, .systemOrange, .systemPink]

        return (0..<count).map { DemoGridPhoto(id: $0, color: palette[$0 % palette.count]) }
    }

    let count: Int
    let columns: Int
    let spacing: CGFloat

    var body: some FLNode {
        FLVGrid(columns: FLGridTracks(integerLiteral: columns), spacing: spacing) {
            FLForEach(Self.photos(count)) { photo in
                FLColor(photo.color)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.roundedRectangle(6))
                    .tag(DemoGridPart.photo(photo.id))
            }
        }
    }
}

struct DemoReactionPicker: FLView {
    static var emojis: [String] {
        ["👍", "🎉", "❤️", "😂", "🤔", "🙌", "🔥", "✅", "👀", "🚀", "💡", "🐛"]
    }

    let minimum: CGFloat

    var body: some FLNode {
        FLVGrid(columns: .adaptive(minimum: minimum), spacing: 6) {
            FLForEach(Self.emojis, id: \.self) { emoji in
                FLButton(tag: DemoGridPart.emoji(emoji)) {
                    FLText(emoji)
                        .font(.systemFont(ofSize: 22))
                        .frame(width: minimum - 8, height: minimum - 8)
                        .background(.tertiarySystemFill, in: .roundedRectangle(8))
                }
            }
        }
        .padding(10)
        .background(.secondarySystemBackground, in: .roundedRectangle(14))
    }
}

struct DemoStickerCarousel: FLView {
    let stickers: Int

    var body: some FLNode {
        FLScroll(.horizontal) {
            FLHGrid(rows: 2, spacing: 8) {
                FLForEach(Array(0..<stickers), id: \.self) { index in
                    FLColor(index.isMultiple(of: 2) ? .systemTeal : .systemPurple)
                        .frame(width: CGFloat(48 + (index % 3) * 24))
                        .clipShape(.roundedRectangle(8))
                }
            }
        }
        .initialContentOffset(contentID: stickers)
        .frame(height: 128)
    }
}

struct DemoDetailTable: FLView {
    var body: some FLNode {
        FLVGrid(columns: [.fixed(96), .flexible()], rowSpacing: 6, columnSpacing: 10, alignment: .leading) {
            FLText("Size").font(.systemFont(ofSize: 12)).foregroundColor(.secondaryLabel)
            FLText("1.2 MB").font(.systemFont(ofSize: 12))

            FLText("Created").font(.systemFont(ofSize: 12)).foregroundColor(.secondaryLabel)
            FLText("Today at 09:41").font(.systemFont(ofSize: 12))

            FLText("Shared with").font(.systemFont(ofSize: 12)).foregroundColor(.secondaryLabel)
            FLText("Ann, Kim and three others").font(.systemFont(ofSize: 12))
        }
    }
}

private struct GridCase<Content: FLView>: View {
    let title: String
    let content: Content
    var width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            Text(measured)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            FLNodePreview(node: content.node, layoutContext: FLContext(width: width))
                .border(.blue.opacity(0.4))
        }
    }

    private var measured: String {
        let size = content.node.layout(in: FLContext(width: width)).size

        return "reserves \(Int(size.width)) × \(Int(size.height)) in a \(Int(width))pt box"
    }
}

private struct GridPlayground: View {
    @State private var photos = 7
    @State private var columns = 3
    @State private var spacing: CGFloat = 4
    @State private var minimum: CGFloat = 44
    @State private var stickers = 9

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("columns are declared, rows are broken for you; a cell gets its column's exact width and no height")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                GridCase(
                    title: "photo grid — \(columns) columns, spacing \(Int(spacing))",
                    content: DemoPhotoGrid(count: photos, columns: columns, spacing: spacing)
                )

                GridCase(
                    title: "reaction picker — adaptive(minimum: \(Int(minimum)))",
                    content: DemoReactionPicker(minimum: minimum)
                )

                GridCase(
                    title: "sticker carousel — two rows, growing right inside a horizontal scroll",
                    content: DemoStickerCarousel(stickers: stickers)
                )

                GridCase(
                    title: "detail table — [.fixed(96), .flexible()]",
                    content: DemoDetailTable()
                )

                controls
            }
            .padding(20)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper("photos: \(photos)", value: $photos, in: 1...18)
                .font(.system(size: 12))

            Stepper("columns: \(columns)", value: $columns, in: 1...6)
                .font(.system(size: 12))

            Stepper("spacing: \(Int(spacing))", value: $spacing, in: 0...16, step: 2)
                .font(.system(size: 12))

            Stepper("adaptive minimum: \(Int(minimum))", value: $minimum, in: 32...96, step: 4)
                .font(.system(size: 12))

            Stepper("stickers: \(stickers)", value: $stickers, in: 1...20)
                .font(.system(size: 12))
        }
    }
}

#Preview("grid: columns, adaptive, and two rows") {
    GridPlayground()
}
