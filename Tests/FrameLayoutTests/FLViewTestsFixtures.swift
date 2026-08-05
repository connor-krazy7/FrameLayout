import Testing
import UIKit
@testable import FrameLayout

struct ComposedCard: FLView {
    let title: String
    var inset: CGFloat = 10

    var body: some FLNode {
        FLColor(.red)
            .frame(width: 40, height: 20)
            .padding(inset)
    }
}

struct ComposedNested: FLView {
    let leading: String
    let trailing: String

    var body: some FLNode {
        FLHStack(spacing: 8) {
            ComposedCard(title: leading)
            FLSpacer()
            ComposedCard(title: trailing)
        }
    }
}
