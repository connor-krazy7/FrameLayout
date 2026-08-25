import Testing
import UIKit

@testable import FrameLayout

enum ButtonRowPart: Hashable, Sendable {
    case send
    case cancel
}

struct ButtonToolbar: FLView {
    let isSendEnabled: Bool

    var body: some FLNode {
        FLHStack(spacing: 8) {
            FLButton(tag: ButtonRowPart.send, style: .scaling(0.94)) {
                FLText("Send")
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.systemBlue, in: .capsule)
            }
            .accessibilityLabel("Send")
            .disabled(!isSendEnabled)

            FLButton(tag: ButtonRowPart.cancel) {
                FLText("Cancel")
                    .foregroundColor(.systemBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
    }
}
