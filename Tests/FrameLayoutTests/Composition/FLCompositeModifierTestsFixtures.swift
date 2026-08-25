import Testing
import UIKit

@testable import FrameLayout

struct NestedPlain: FLView {
    var body: some FLNode {
        FLColor(.systemBlue).frame(width: 40, height: 20)
    }
}
