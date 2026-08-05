import FrameLayout
import SwiftUI
import UIKit

struct FLNodePreview<Node: FLNode>: View {
    let node: Node
    var layoutContext: FLContext = FLContext(width: 300)

    var body: some View {
        FLHostView<Node>.asViewRepresentable(
            customise: { host in
                host.apply(node: node, layout: node.layout(in: layoutContext))
            },
            calculateSize: { _, _ in
                node.layout(in: layoutContext).size
            }
        )
    }
}

enum FLChainSamples {
    typealias Swatch = FLFrame<FLColor>
    typealias NestedRings = FLDecorated<FLPadded<FLDecorated<FLPadded<FLDecorated<Swatch>>>>>
    typealias AdjacentBackgrounds = FLDecorated<FLDecorated<Swatch>>
    typealias TranslucentStack = FLDecorated<FLDecorated<Swatch>>
    typealias TextBlock = FLDecorated<FLPadded<FLText>>
    typealias Bubble = FLDecorated<FLPadded<FLText>>
    typealias Badge = FLDecorated<FLPadded<FLText>>
    typealias ZStacked = FLZStack<FLConcat<FLSingle<Swatch>, FLSingle<Swatch>>>
    typealias BackedText = FLBackground<FLPadded<FLText>, FLDecorated<FLColor>>
    typealias BadgedSwatch = FLOverlay<Swatch, Badge>

    static var previewWidth: CGFloat { 240 }
    static var textInset: CGFloat { 8 }

    static var sampleText: String {
        "Every node here is a single-child generic wrapper, so the content tree and the view tree are the same type by construction."
    }

    static func textBlock(lineLimit: Int, lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> TextBlock {
        FLText(sampleText)
            .font(.systemFont(ofSize: 16))
            .foregroundColor(.label)
            .lineLimit(lineLimit)
            .lineBreakMode(lineBreakMode)
            .padding(textInset)
            .background(.secondarySystemBackground)
    }

    static func centeredTextBlock(lineLimit: Int) -> TextBlock {
        FLText(sampleText)
            .font(.systemFont(ofSize: 16))
            .foregroundColor(.label)
            .lineLimit(lineLimit)
            .lineBreakMode(.byTruncatingTail)
            .multilineTextAlignment(.center)
            .padding(textInset)
            .background(.secondarySystemBackground)
    }

    static func bubble(_ text: String, corners: FLCorners) -> Bubble {
        FLText(text)
            .font(.systemFont(ofSize: 15))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.systemBlue, in: .roundedRectangle(18), corners: corners, curve: .continuous)
    }

    static var groupedBubbleCorners: [(label: String, corners: FLCorners)] {
        [
            ("first — .all minus .bottomTrailing", FLCorners.all.subtracting(.bottomTrailing)),
            ("middle — .all minus .trailing", FLCorners.all.subtracting(.trailing)),
            ("last — .all minus .topTrailing", FLCorners.all.subtracting(.topTrailing))
        ]
    }

    static var zStacked: ZStacked {
        FLZStack(alignment: .bottomTrailing) {
            FLColor(.systemTeal).frame(width: 80, height: 60)
            FLColor(UIColor.systemPurple.withAlphaComponent(0.8)).frame(width: 40, height: 40)
        }
    }

    static var backedText: BackedText {
        FLText("sized to content")
            .font(.systemFont(ofSize: 15))
            .foregroundColor(.white)
            .padding(10)
            .background(
                FLColor(.systemIndigo).clipShape(.roundedRectangle(10), curve: .continuous)
            )
    }

    static var badge: Badge {
        FLText("9")
            .font(.systemFont(ofSize: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.systemRed, in: .capsule)
    }

    static var badgedSwatch: BadgedSwatch {
        FLColor(.systemTeal)
            .frame(width: 80, height: 60)
            .overlay(badge, alignment: .topTrailing)
    }

    static var nestedRings: NestedRings {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(.systemRed)
            .padding(10)
            .background(.systemBlue)
            .padding(10)
            .background(.systemYellow)
    }

    static var adjacentBackgrounds: AdjacentBackgrounds {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(.systemBlue)
            .background(.systemYellow)
    }

    static var translucentStack: TranslucentStack {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(UIColor.systemBlue.withAlphaComponent(0.5))
            .background(.systemYellow)
    }

    static var translucentRings: NestedRings {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(UIColor.systemRed.withAlphaComponent(0.5))
            .padding(10)
            .background(UIColor.systemBlue.withAlphaComponent(0.5))
            .padding(10)
            .background(UIColor.systemYellow.withAlphaComponent(0.5))
    }

    static var stackedSameAlpha: NestedRings {
        let ink = UIColor.black.withAlphaComponent(0.3)

        return FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(ink)
            .padding(10)
            .background(ink)
            .padding(10)
            .background(ink)
    }

    static var backgroundThenPadding: FLPadded<FLDecorated<Swatch>> {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .background(UIColor.systemIndigo.withAlphaComponent(0.6))
            .padding(10)
    }

    static var paddingThenBackground: FLDecorated<FLPadded<Swatch>> {
        FLColor(.clear)
            .frame(width: 40, height: 40)
            .padding(10)
            .background(UIColor.systemIndigo.withAlphaComponent(0.6))
    }
}

private struct ComparisonRow<Node: FLNode, Reference: View>: View {
    let title: String
    let note: String
    let node: Node
    var layoutWidth: CGFloat = FLChainSamples.previewWidth
    @ViewBuilder let reference: () -> Reference

    private var measuredSize: CGSize {
        node.layout(in: FLContext(width: layoutWidth)).size
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            labelled("SwiftUI") { reference() }
            labelled("FrameLayout — \(Int(measuredSize.width))x\(Int(measuredSize.height))") {
                FLNodePreview(node: node, layoutContext: FLContext(width: layoutWidth))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func labelled(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
            content()
        }
    }
}

private struct PaddingBackgroundCases: View {
    var body: some View {
        CaseGroup("Opaque padding / background") {
            ComparisonRow(
                title: "Alternating padding / background",
                note: "Expected identical: 80x80 outer, 10pt yellow ring, 10pt blue ring, 40x40 red.",
                node: FLChainSamples.nestedRings
            ) {
                Color.red
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .background(.blue)
                    .padding(10)
                    .background(.yellow)
            }

            ComparisonRow(
                title: "background then padding",
                note: "Padding is outside the fill, so the 10pt margin stays transparent. Outer 60x60, colour only in the middle 40x40.",
                node: FLChainSamples.backgroundThenPadding
            ) {
                Color.clear
                    .frame(width: 40, height: 40)
                    .background(Color(uiColor: .systemIndigo.withAlphaComponent(0.6)))
                    .padding(10)
            }

            ComparisonRow(
                title: "padding then background",
                note: "Padding is inside the fill, so the whole 60x60 is coloured. Same two modifiers, opposite order, different result.",
                node: FLChainSamples.paddingThenBackground
            ) {
                Color.clear
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .background(Color(uiColor: .systemIndigo.withAlphaComponent(0.6)))
            }
        }
    }
}

private struct AlphaCases: View {
    var body: some View {
        CaseGroup("Alpha compositing") {
            ComparisonRow(
                title: "Adjacent backgrounds — opaque",
                note: "Each modifier wraps, so yellow sits behind blue and blue wins. Both should read solid blue.",
                node: FLChainSamples.adjacentBackgrounds
            ) {
                Color.clear
                    .frame(width: 40, height: 40)
                    .background(.blue)
                    .background(.yellow)
            }

            ComparisonRow(
                title: "Adjacent backgrounds — translucent",
                note: "The case merging could never express: 50% blue composites over yellow, so both read green-ish — neither blue nor yellow.",
                node: FLChainSamples.translucentStack
            ) {
                Color.clear
                    .frame(width: 40, height: 40)
                    .background(.blue.opacity(0.5))
                    .background(.yellow)
            }

            ComparisonRow(
                title: "Translucent rings, alternating padding",
                note: "Three 50% fills at 80/60/40. The centre composites all three, the middle ring two, the outer ring one — so each band must differ.",
                node: FLChainSamples.translucentRings
            ) {
                Color.red.opacity(0.5)
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .background(.blue.opacity(0.5))
                    .padding(10)
                    .background(.yellow.opacity(0.5))
            }

            ComparisonRow(
                title: "Same colour stacked three times (black 30%)",
                note: "Cumulative alpha is measurable: outer ring 0.30, middle 0.51, centre 0.657. Three visibly distinct greys, evenly stepped.",
                node: FLChainSamples.stackedSameAlpha
            ) {
                Color.black.opacity(0.3)
                    .frame(width: 40, height: 40)
                    .padding(10)
                    .background(.black.opacity(0.3))
                    .padding(10)
                    .background(.black.opacity(0.3))
            }
        }
    }
}

private struct LayeringCases: View {
    var body: some View {
        CaseGroup("ZStack, background, overlay") {
            ComparisonRow(
                title: "FLZStack — sizes to the union of children",
                note: "80x60 teal behind a 40x40 purple, aligned bottomTrailing. The stack takes the larger child's size in each axis.",
                node: FLChainSamples.zStacked
            ) {
                ZStack(alignment: .bottomTrailing) {
                    Color.teal.frame(width: 80, height: 60)
                    Color.purple.opacity(0.8).frame(width: 40, height: 40)
                }
            }

            ComparisonRow(
                title: "background(FLNode) — sizes to the content",
                note: "The background is proposed exactly the content's size, so it cannot grow the parent. This is the difference from FLZStack.",
                node: FLChainSamples.backedText
            ) {
                Text("sized to content")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ComparisonRow(
                title: "overlay(FLNode, alignment: .topTrailing)",
                note: "Same layout rule as background, drawn above instead of behind. Z-order is structural — the view adds children in a fixed order.",
                node: FLChainSamples.badgedSwatch
            ) {
                Color.teal
                    .frame(width: 80, height: 60)
                    .overlay(alignment: .topTrailing) {
                        Text("9")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red, in: Capsule())
                    }
            }
        }
    }
}

private struct CornerCases: View {
    var body: some View {
        CaseGroup("Selective corners") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Grouped bubbles — trailing corners dropped where messages join")
                    .font(.subheadline.weight(.semibold))
                Text("FLCorners is leading/trailing, so the flattened side mirrors under RTL while top/bottom stay put. Resolved at layout time from FLContext.layoutDirection, not from the view.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(FLChainSamples.groupedBubbleCorners.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.label)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                        FLNodePreview(
                            node: FLChainSamples.bubble("Message body", corners: entry.corners),
                            layoutContext: FLContext(width: FLChainSamples.previewWidth)
                        )
                    }
                }

                Text("same three, RTL")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)

                ForEach(Array(FLChainSamples.groupedBubbleCorners.enumerated()), id: \.offset) { _, entry in
                    FLNodePreview(
                        node: FLChainSamples.bubble("Message body", corners: entry.corners),
                        layoutContext: FLContext(width: FLChainSamples.previewWidth, layoutDirection: .rightToLeft)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TextCases: View {
    private let width = FLChainSamples.previewWidth
    private let inset = FLChainSamples.textInset

    var body: some View {
        CaseGroup("Text: lineLimit + alignment") {
            ForEach([1, 2, 3, 0], id: \.self) { limit in
                ComparisonRow(
                    title: limit == 0 ? "lineLimit: unlimited" : "lineLimit: \(limit)",
                    note: "Measured with TextKit maximumNumberOfLines, rendered by UILabel. Heights must match.",
                    node: FLChainSamples.textBlock(lineLimit: limit),
                    layoutWidth: width
                ) {
                    Text(FLChainSamples.sampleText)
                        .font(.system(size: 16))
                        .lineLimit(limit == 0 ? nil : limit)
                        .frame(width: width - inset * 2, alignment: .leading)
                        .padding(inset)
                        .background(Color(uiColor: .secondarySystemBackground))
                }
            }

            ComparisonRow(
                title: "multilineTextAlignment(.center), lineLimit 3",
                note: "Alignment is written into NSParagraphStyle, so it affects lines narrower than the widest one.",
                node: FLChainSamples.centeredTextBlock(lineLimit: 3),
                layoutWidth: width
            ) {
                Text(FLChainSamples.sampleText)
                    .font(.system(size: 16))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(width: width - inset * 2)
                    .padding(inset)
                    .background(Color(uiColor: .secondarySystemBackground))
            }
        }
    }
}

private struct CaseGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CasesScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                content()
            }
            .padding(20)
        }
    }
}

#Preview("all cases") {
    CasesScroll {
        PaddingBackgroundCases()
        Divider()
        AlphaCases()
        Divider()
        LayeringCases()
        Divider()
        CornerCases()
        Divider()
        TextCases()
    }
}

#Preview("padding + background") {
    CasesScroll { PaddingBackgroundCases() }
}

#Preview("alpha compositing") {
    CasesScroll { AlphaCases() }
}

#Preview("layering") {
    CasesScroll { LayeringCases() }
}

#Preview("selective corners") {
    CasesScroll { CornerCases() }
}

#Preview("lineLimit + alignment") {
    CasesScroll { TextCases() }
}
