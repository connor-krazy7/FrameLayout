import UIKit

public enum FLAspectContentMode: Sendable, Hashable {
    /// The largest size with the ratio that fits inside the proposal.
    case fit
    /// The smallest size with the ratio that covers the proposal.
    case fill
}
