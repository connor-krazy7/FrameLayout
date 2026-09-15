import FrameLayout
import SwiftUI
import UIKit

/// The absent half of `if condition { … }`, run through FL and SwiftUI twice: hosted on its own, where
/// both systems still resolve the modifiers wrapped around it, and inside a stack, where both give it no
/// slot at all. A root measurement reports 20x20 for a padded absent optional that occupies nothing
/// wherever it is actually used, which is what the two readings side by side are here to show.
enum FLAbsentOptionalSamples {
    static var previewWidth: CGFloat { 240 }
    static var swatch: CGFloat { 40 }
    static var spacing: CGFloat { 8 }
    static var inset: CGFloat { 10 }
    static var pinned: CGFloat { 100 }

    @FLNodeBuilder static func node(_ isVisible: Bool) -> FLOptional<FLFrame<FLColor>> {
        if isVisible {
            FLColor(.systemRed).frame(width: swatch, height: swatch)
        }
    }

    @ViewBuilder static func view(_ isVisible: Bool) -> some View {
        if isVisible {
            Color.red.frame(width: swatch, height: swatch)
        }
    }

    static func stackNode(_ sample: some FLNode) -> some FLNode {
        FLVStack(alignment: .leading, spacing: spacing) {
            FLColor(.systemTeal).frame(width: swatch, height: swatch)
            sample
            FLColor(.systemIndigo).frame(width: swatch, height: swatch)
        }
    }

    static func stackView(_ sample: some View) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Color.teal.frame(width: swatch, height: swatch)
            sample
            Color.indigo.frame(width: swatch, height: swatch)
        }
    }
}

// MARK: - Measurement

private extension View {
    func outlined() -> some View {
        overlay(
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.tertiary)
        )
    }
}

private enum SizeText {
    static func size(_ size: CGSize) -> String {
        "\(number(size.width))x\(number(size.height))"
    }

    static func number(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Rows

private struct ComparisonRow<Node: FLNode, Reference: View>: View {
    let title: String
    let note: String
    let node: Node
    @ViewBuilder let reference: () -> Reference

    private var width: CGFloat { FLAbsentOptionalSamples.previewWidth }
    private var context: FLContext { FLContext(width: width) }

    private var flAlone: CGSize { node.layout(in: context).size }
    private var flStacked: CGFloat { FLAbsentOptionalSamples.stackNode(node).layout(in: context).size.height }

    private var swiftUIAlone: CGSize {
        UIHostingController(rootView: reference()).sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity))
    }

    private var swiftUIStacked: CGFloat {
        UIHostingController(rootView: FLAbsentOptionalSamples.stackView(reference()))
            .sizeThatFits(in: CGSize(width: width, height: CGFloat.infinity)).height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold).monospaced())
            Text(note)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            section(
                "hosted alone",
                swiftUI: SizeText.size(swiftUIAlone),
                fl: SizeText.size(flAlone),
                agrees: abs(flAlone.width - swiftUIAlone.width) <= 0.5 && abs(flAlone.height - swiftUIAlone.height) <= 0.5
            ) {
                reference().outlined()
            } flContent: {
                FLNodePreview(node: node, layoutContext: context).outlined()
            }

            section(
                "in a stack, between two \(Int(FLAbsentOptionalSamples.swatch))pt swatches",
                swiftUI: "height \(SizeText.number(swiftUIStacked))",
                fl: "height \(SizeText.number(flStacked))",
                agrees: abs(flStacked - swiftUIStacked) <= 0.5
            ) {
                FLAbsentOptionalSamples.stackView(reference()).outlined()
            } flContent: {
                FLNodePreview(node: FLAbsentOptionalSamples.stackNode(node), layoutContext: context).outlined()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(
        _ caption: String,
        swiftUI: String,
        fl: String,
        agrees: Bool,
        @ViewBuilder swiftUIContent: () -> some View,
        @ViewBuilder flContent: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                column("SwiftUI — \(swiftUI)", agrees: agrees, content: swiftUIContent)
                column("FrameLayout — \(fl)", agrees: agrees, content: flContent)
            }
        }
    }

    private func column(_ caption: String, agrees: Bool, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption2.monospaced())
                .foregroundStyle(agrees ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Cases

private struct ModifierCases: View {
    let isVisible: Bool

    private var inset: CGFloat { FLAbsentOptionalSamples.inset }
    private var pinned: CGFloat { FLAbsentOptionalSamples.pinned }

    var body: some View {
        CaseGroup("What survives an absent optional") {
            ComparisonRow(
                title: "optionalView",
                note: "Nothing to reserve, so the two readings agree and both are zero.",
                node: FLAbsentOptionalSamples.node(isVisible)
            ) {
                FLAbsentOptionalSamples.view(isVisible)
            }

            ComparisonRow(
                title: ".padding(\(Int(inset)))",
                note: "Hosted alone the insets resolve around nothing, \(Int(inset * 2))x\(Int(inset * 2)). In a stack the child is dropped and the insets go with it.",
                node: FLAbsentOptionalSamples.node(isVisible).padding(inset)
            ) {
                FLAbsentOptionalSamples.view(isVisible).padding(inset)
            }

            ComparisonRow(
                title: ".frame(width: \(Int(pinned)), height: \(Int(pinned)))",
                note: "A pinned frame answers from itself, so alone it is \(Int(pinned))x\(Int(pinned)) — and still nothing in a stack. Reserve space with FLColor(.clear), which is present and empty, not with an absent child in a frame.",
                node: FLAbsentOptionalSamples.node(isVisible).frame(width: pinned, height: pinned)
            ) {
                FLAbsentOptionalSamples.view(isVisible).frame(width: pinned, height: pinned)
            }

            ComparisonRow(
                title: ".frame(maxWidth: \(Int(pinned)))",
                note: "A bounded axis follows the clamped proposal, so the width survives the child going away — alone. The slot does not.",
                node: FLAbsentOptionalSamples.node(isVisible).frame(maxWidth: pinned)
            ) {
                FLAbsentOptionalSamples.view(isVisible).frame(maxWidth: pinned)
            }

            ComparisonRow(
                title: ".padding(\(Int(inset))).background(colour)",
                note: "The box survives hosted alone but nothing is drawn in it, which is the pair to watch: agreeing sizes are not agreeing pixels.",
                node: FLAbsentOptionalSamples.node(isVisible).padding(inset).background(.systemGreen)
            ) {
                FLAbsentOptionalSamples.view(isVisible).padding(inset).background(Color.green)
            }

            ComparisonRow(
                title: "FLScroll { optionalView }",
                note: "The boundary: a scroll view is a thing of its own, so it does not forward isAbsent and keeps its slot — \(Int(FLAbsentOptionalSamples.swatch) * 2 + Int(FLAbsentOptionalSamples.spacing) * 2) against \(Int(FLAbsentOptionalSamples.swatch) * 2 + Int(FLAbsentOptionalSamples.spacing)) for the rows above. SwiftUI agrees.",
                node: FLScroll { FLAbsentOptionalSamples.node(isVisible) }
            ) {
                ScrollView { FLAbsentOptionalSamples.view(isVisible) }
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
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Every row at one setting of the condition. Rendered on its own by `FLAbsentOptionalComparisonTests`,
/// which is why it is a type rather than a closure inside the preview.
struct FLAbsentOptionalCases: View {
    let isVisible: Bool

    var body: some View {
        ModifierCases(isVisible: isVisible)
    }
}

private struct AbsentOptionalComparison: View {
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Toggle("condition", isOn: $isVisible)
                    .font(.subheadline.weight(.semibold))
                Text("Off is the absent case. An orange caption marks a row where the two systems disagree; none should.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                FLAbsentOptionalCases(isVisible: isVisible)
            }
            .padding(20)
        }
    }
}

#Preview("absent optional") {
    AbsentOptionalComparison()
}
