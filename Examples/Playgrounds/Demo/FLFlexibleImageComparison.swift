import FrameLayout
import SwiftUI
import UIKit

/// The conversation-photo case: pixel dimensions are known from the model before anything loads, so the
/// box can be reserved up front. Each row runs the same chain through FL and SwiftUI at the same offered
/// width, using `aspectRatio(_:contentMode:boundedBy:)` on the FL side and the `maxHeight × ratio`
/// arithmetic it replaces on the SwiftUI side.
struct FlexiblePhotoSample: Identifiable, Sendable {
    static var maximumHeight: CGFloat { 140 }

    static var samples: [FlexiblePhotoSample] {
        [
            FlexiblePhotoSample(id: "wide", pixelSize: FLSize(width: 1600, height: 900), color: .systemBlue),
            FlexiblePhotoSample(id: "tall", pixelSize: FLSize(width: 900, height: 1600), color: .systemPink),
            FlexiblePhotoSample(id: "square", pixelSize: FLSize(width: 800, height: 800), color: .systemPurple),
            FlexiblePhotoSample(id: "panorama", pixelSize: FLSize(width: 2400, height: 600), color: .systemTeal),
            FlexiblePhotoSample(id: "thumbnail", pixelSize: FLSize(width: 60, height: 40), color: .systemGreen),
        ]
    }

    let id: String
    let pixelSize: FLSize
    let color: UIColor

    var ratio: CGFloat { pixelSize.width / pixelSize.height }

    /// Stands in for the loaded photo. Rendered small — the reserved box comes from `pixelSize`, never
    /// from the bytes, which is the whole point of the case.
    var image: UIImage { FLImageSamples.swatch(size: renderSize, color: color) }

    var summary: String {
        "\(id) — \(Int(pixelSize.width))×\(Int(pixelSize.height)), ratio \(String(format: "%.2f", ratio))"
    }

    private var renderSize: CGSize {
        let scale = min(1, 240 / max(pixelSize.width, pixelSize.height))

        return CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
    }
}

private struct FlexibleRow: View {
    let sample: FlexiblePhotoSample
    let boxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sample.summary)
                .font(.system(size: 12, weight: .semibold))

            Text(measured)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                labelled("FL") {
                    FLNodePreview(node: flNode, layoutContext: FLContext(width: boxWidth))
                }

                labelled("SwiftUI") {
                    swiftUIPhoto
                }
            }
        }
    }

    private var flNode: some FLNode {
        FLImage(sample.image)
            .resizable()
            .aspectRatio(
                sample.ratio,
                contentMode: .fit,
                boundedBy: CGSize(
                    width: sample.pixelSize.width,
                    height: FlexiblePhotoSample.maximumHeight
                )
            )
            .background(.tertiarySystemFill, in: .roundedRectangle(12))
            .clipped()
    }

    private var swiftUIPhoto: some View {
        Image(uiImage: sample.image)
            .resizable()
            .aspectRatio(sample.ratio, contentMode: .fit)
            .frame(maxWidth: min(sample.pixelSize.width, FlexiblePhotoSample.maximumHeight * sample.ratio))
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            .clipped()
    }

    private var measured: String {
        let size = flNode.layout(in: FLContext(width: boxWidth)).size
        let capped = min(sample.pixelSize.width, FlexiblePhotoSample.maximumHeight * sample.ratio)

        return "reserves \(Int(size.width)) × \(Int(size.height)) in \(Int(boxWidth))pt — width cap \(Int(capped))"
    }

    private func labelled(_ name: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            content()
                .fixedSize(horizontal: false, vertical: true)
                .border(.blue)
                .frame(width: boxWidth, alignment: .leading)
                .border(.red.opacity(0.6))
        }
    }
}

private struct UnloadedRow: View {
    let sample: FlexiblePhotoSample
    let boxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(sample.id) — box reserved with no image at all")
                .font(.system(size: 12, weight: .semibold))

            Text(measured)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            FLNodePreview(node: node, layoutContext: FLContext(width: boxWidth))
                .border(.blue)
                .frame(width: boxWidth, alignment: .leading)
                .border(.red.opacity(0.6))
        }
    }

    private var node: some FLNode {
        FLImage(nil)
            .resizable()
            .aspectRatio(
                sample.ratio,
                contentMode: .fit,
                boundedBy: CGSize(
                    width: sample.pixelSize.width,
                    height: FlexiblePhotoSample.maximumHeight
                )
            )
            .background(.tertiarySystemFill, in: .roundedRectangle(12))
    }

    private var measured: String {
        let size = node.layout(in: FLContext(width: boxWidth)).size

        return "reserves \(Int(size.width)) × \(Int(size.height)) before the bytes arrive"
    }
}

private struct FlexibleCases: View {
    let boxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("cap \(Int(FlexiblePhotoSample.maximumHeight))pt tall, offered \(Int(boxWidth))pt wide")
                .font(.system(size: 11, weight: .medium))

            Text("blue border is the reserved box, red is the offered width")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            ForEach(FlexiblePhotoSample.samples) { sample in
                FlexibleRow(sample: sample, boxWidth: boxWidth)
            }

            Divider()

            UnloadedRow(sample: FlexiblePhotoSample.samples[1], boxWidth: boxWidth)
        }
        .padding(20)
    }
}

#Preview("flexible: 240pt box") {
    ScrollView { FlexibleCases(boxWidth: 240) }
}

#Preview("flexible: 120pt box") {
    ScrollView { FlexibleCases(boxWidth: 120) }
}

#Preview("flexible: 320pt box") {
    ScrollView { FlexibleCases(boxWidth: 320) }
}
