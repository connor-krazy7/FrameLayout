import UIKit

public struct FLStackGeometry: Sendable, Equatable {
    public let size: CGSize
    public let childFrames: [CGRect]

    public static var empty: FLStackGeometry { FLStackGeometry(size: .zero, childFrames: []) }
}
