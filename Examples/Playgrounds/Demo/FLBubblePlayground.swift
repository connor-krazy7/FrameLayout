import FrameLayout
import SwiftUI
import UIKit

struct DemoTailedBubble: FLView {
    let text: String
    let radii: FLCornerRadii
    let colour: UIColor

    var body: some FLNode {
        FLText(text)
            .font(.systemFont(ofSize: 16))
            .foregroundColor(.white)
            .padding(12)
            .background(colour, in: .unevenRoundedRectangle(radii))
    }
}

enum DemoBubbleTailSamples {
    static let outgoing = FLCornerRadii(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 20,
        bottomTrailing: 4
    )

    static let incoming = FLCornerRadii(
        topLeading: 20,
        topTrailing: 20,
        bottomLeading: 4,
        bottomTrailing: 20
    )

    /// The strip runs to the bottom edge, so its own corners are square until the bubble clips them.
    /// `clipped(_:)` collapses into the background's decoration only because this is a chain rather
    /// than an `FLView` — through a composite it would wrap a second, rectangular one instead.
    static func striped(_ text: String, clips: Bool) -> some FLNode {
        FLVStack(alignment: .leading, spacing: 10) {
            FLText(text)
                .font(.systemFont(ofSize: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            FLColor(.systemYellow)
                .frame(height: 14)
        }
        .background(.systemTeal, in: .unevenRoundedRectangle(outgoing))
        .clipped(clips)
    }
}

#Preview("uneven corner radii") {
    FLNodePreview(
        node: FLVStack(alignment: .leading, spacing: 16) {
            DemoTailedBubble(
                text: "The tail corner is 4, the other three are 20.",
                radii: DemoBubbleTailSamples.outgoing,
                colour: .systemBlue
            )

            DemoTailedBubble(
                text: "Mirrored, for the other side of the thread.",
                radii: DemoBubbleTailSamples.incoming,
                colour: .systemGray
            )

            DemoTailedBubble(
                text: "A border is stroked along the same outline.",
                radii: DemoBubbleTailSamples.outgoing,
                colour: .systemIndigo
            )
            .border(.label, width: 2)

            DemoBubbleTailSamples.striped("Clipped: the strip takes the outline.", clips: true)

            DemoBubbleTailSamples.striped("Unclipped: the strip keeps its corners.", clips: false)
        },
        layoutContext: FLContext(width: 260)
    )
    .padding(20)
}
