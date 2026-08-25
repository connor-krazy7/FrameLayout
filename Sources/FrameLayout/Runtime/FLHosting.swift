import UIKit

@MainActor
public protocol FLHosting: UIView {
    var contentSize: CGSize { get }
}
