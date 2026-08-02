import SwiftUI
import UIKit

enum FLImageSamples {
    static var boxWidth: CGFloat { 160 }

    static var landscape: UIImage { swatch(size: CGSize(width: 160, height: 90), color: .systemBlue) }
    static var portrait: UIImage { swatch(size: CGSize(width: 60, height: 120), color: .systemPink) }
    static var tiny: UIImage { swatch(size: CGSize(width: 40, height: 30), color: .systemGreen) }

    static func swatch(size: CGSize, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.9).setStroke()
            context.cgContext.setLineWidth(4)
            context.cgContext.strokeEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6))
        }
    }
}

private struct ComparisonRow<FLContent: FLNode, SwiftUIContent: View>: View {
    let title: String
    let node: FLContent
    @ViewBuilder let swiftUI: () -> SwiftUIContent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            Text(measured)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                labelled("FL") {
                    FLNodePreview(node: node, layoutContext: FLContext(width: FLImageSamples.boxWidth))
                }

                labelled("SwiftUI") {
                    swiftUI()
                }
            }
        }
    }

    private var measured: String {
        let size = node.layout(in: FLContext(width: FLImageSamples.boxWidth)).size

        return "FL reserves \(Int(size.width)) × \(Int(size.height)) in a \(Int(FLImageSamples.boxWidth))pt box"
    }

    private func labelled(_ name: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            content()
                .border(.blue)
                .frame(width: FLImageSamples.boxWidth, alignment: .leading)
                .border(.red.opacity(0.6))
        }
    }
}

private struct IntrinsicCases: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "no resizable — reports its own point size",
                node: FLImage(FLImageSamples.landscape)
            ) {
                Image(uiImage: FLImageSamples.landscape)
            }

            ComparisonRow(
                title: "resizable — takes the proposal on both axes",
                node: FLImage(FLImageSamples.landscape).resizable()
            ) {
                Image(uiImage: FLImageSamples.landscape).resizable()
            }
        }
    }
}

private struct AspectCases: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "aspectRatio(.fit) — largest that fits the proposal",
                node: FLImage(FLImageSamples.landscape).resizable().aspectRatio(16.0 / 9, contentMode: .fit)
            ) {
                Image(uiImage: FLImageSamples.landscape).resizable().aspectRatio(16.0 / 9, contentMode: .fit)
            }

            ComparisonRow(
                title: "aspectRatio(.fill) — smallest that covers it, so one axis spills",
                node: FLImage(FLImageSamples.landscape).resizable().aspectRatio(16.0 / 9, contentMode: .fill)
            ) {
                Image(uiImage: FLImageSamples.landscape).resizable().aspectRatio(16.0 / 9, contentMode: .fill)
            }

            ComparisonRow(
                title: "aspectRatio(.fill) + frame(maxHeight: 140) — bounded, so nothing is supplied to fill",
                node: FLImage(FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(maxHeight: 140)
            ) {
                Image(uiImage: FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(maxHeight: 140)
            }

            ComparisonRow(
                title: "aspectRatio(.fill) + frame(height: 140) — a supplied height, so the width spills",
                node: FLImage(FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(height: 140)
            ) {
                Image(uiImage: FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(height: 140)
            }

            ComparisonRow(
                title: "aspectRatio(.fill) in a fixed frame, clipped",
                node: FLImage(FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(width: FLImageSamples.boxWidth, height: 60)
                    .clipped()
            ) {
                Image(uiImage: FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fill)
                    .frame(width: FLImageSamples.boxWidth, height: 60)
                    .clipped()
            }
        }
    }
}

private struct ContentModeCases: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "portrait in a square frame — scaleAspectFit / .fit",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .contentMode(.scaleAspectFit)
                    .frame(width: 80, height: 80)
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }

            ComparisonRow(
                title: "portrait in a square frame — scaleAspectFill / .fill, clipped",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .contentMode(.scaleAspectFill)
                    .frame(width: 80, height: 80)
                    .clipped()
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
            }

            ComparisonRow(
                title: "portrait in a square frame — scaleToFill / resizable alone, stretched",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .contentMode(.scaleToFill)
                    .frame(width: 80, height: 80)
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .frame(width: 80, height: 80)
            }
        }
    }
}

private struct RatioCapCases: View {
    private static var portraitRatio: CGFloat {
        FLImageSamples.portrait.size.width / FLImageSamples.portrait.size.height
    }

    private static var cap: CGFloat { 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "tall photo, fit + frame(maxHeight: 100) + clipped — the box shrinks, the photo is cropped",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
                    .clipped()
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
                    .clipped()
            }

            ComparisonRow(
                title: "same cap expressed on the width — frame(maxWidth: 100 × ratio) — actually fits",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxWidth: Self.cap * Self.portraitRatio)
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxWidth: Self.cap * Self.portraitRatio)
            }

            ComparisonRow(
                title: "an exact frame(height: 100) also fits, but always spends the full 100",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(height: Self.cap)
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(height: Self.cap)
            }

            ComparisonRow(
                title: "landscape photo, fit + frame(maxHeight: 100) — nothing to cap, so it is untouched",
                node: FLImage(FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
            ) {
                Image(uiImage: FLImageSamples.landscape)
                    .resizable()
                    .aspectRatio(16.0 / 9, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
            }

            ComparisonRow(
                title: "the same cap without clipping — both systems let the photo spill out of the box",
                node: FLImage(FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
            ) {
                Image(uiImage: FLImageSamples.portrait)
                    .resizable()
                    .aspectRatio(Self.portraitRatio, contentMode: .fit)
                    .frame(maxHeight: Self.cap)
            }
        }
    }
}

private struct SmallImageCases: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "tiny image, resizable — blown up to the proposal",
                node: FLImage(FLImageSamples.tiny).resizable().aspectRatio(4.0 / 3, contentMode: .fit)
            ) {
                Image(uiImage: FLImageSamples.tiny).resizable().aspectRatio(4.0 / 3, contentMode: .fit)
            }

            ComparisonRow(
                title: "tiny image, capped at its own width — left alone",
                node: FLImage(FLImageSamples.tiny)
                    .resizable()
                    .aspectRatio(4.0 / 3, contentMode: .fit)
                    .frame(maxWidth: 40)
            ) {
                Image(uiImage: FLImageSamples.tiny)
                    .resizable()
                    .aspectRatio(4.0 / 3, contentMode: .fit)
                    .frame(maxWidth: 40)
            }
        }
    }
}

private struct TintCases: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ComparisonRow(
                title: "symbol, untinted",
                node: FLImage(UIImage(systemName: "photo.fill")).resizable().frame(width: 44, height: 44)
            ) {
                Image(systemName: "photo.fill").resizable().frame(width: 44, height: 44)
            }

            ComparisonRow(
                title: "symbol, tinted — template rendering",
                node: FLImage(UIImage(systemName: "photo.fill"))
                    .resizable()
                    .foregroundColor(.systemPink)
                    .frame(width: 44, height: 44)
            ) {
                Image(systemName: "photo.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.pink)
            }
        }
    }
}

private struct ImageCasesScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("blue border is the content, red is the \(Int(FLImageSamples.boxWidth))pt box it was offered")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                content()
            }
            .padding(20)
        }
    }
}

#Preview("image: FL vs SwiftUI") {
    ImageCasesScroll {
        IntrinsicCases()
        Divider()
        AspectCases()
        Divider()
        ContentModeCases()
        Divider()
        RatioCapCases()
        Divider()
        SmallImageCases()
        Divider()
        TintCases()
    }
}

#Preview("image: intrinsic + resizable") {
    ImageCasesScroll { IntrinsicCases() }
}

#Preview("image: aspect ratio") {
    ImageCasesScroll { AspectCases() }
}

#Preview("image: content mode") {
    ImageCasesScroll { ContentModeCases() }
}

#Preview("image: capping a ratio photo") {
    ImageCasesScroll { RatioCapCases() }
}
