import Testing
import UIKit

@testable import FrameLayout

enum AnimationPart: Hashable, Sendable {
    case plain
    case animated
}

struct AnimationRow: FLView {
    let height: CGFloat
    let animation: FLAnimation?

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 4) {
            FLColor(.systemGray4)
                .frame(width: 100, height: height)
                .tag(AnimationPart.plain)

            FLColor(.systemBlue)
                .frame(width: 100, height: height)
                .tag(AnimationPart.animated)
                .animation(animation)
        }
    }
}

struct AnimationValueRow: FLView {
    let height: CGFloat
    let tracked: Int

    var body: some FLNode {
        FLColor(.systemBlue)
            .frame(width: 100, height: height)
            .tag(AnimationPart.animated)
            .animation(.linear(0.3), value: tracked)
    }
}
