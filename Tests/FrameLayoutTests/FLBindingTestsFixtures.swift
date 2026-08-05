import Testing
import UIKit

@testable import FrameLayout

enum BindingPart: Hashable, Sendable {
    case always
    case sometimes
}

struct BindingRow: FLView {
    let showsOptional: Bool

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLButton(tag: BindingPart.always) {
                FLColor(.systemBlue).frame(width: 80, height: 30)
            }

            if showsOptional {
                FLButton(tag: BindingPart.sometimes) {
                    FLColor(.systemGreen).frame(width: 80, height: 30)
                }
            }
        }
    }
}
