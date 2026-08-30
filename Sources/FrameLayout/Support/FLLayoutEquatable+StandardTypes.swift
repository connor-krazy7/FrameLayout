import UIKit

// A generated or hand-written conformance compares each field as
// `field.isLayoutEquivalent(to: other.field)`, so every stored type has to conform. These take the
// default, which is `==`. A type absent from this list is a compile error at the property that stores
// it, fixed by a one-line conformance — never a silent fallback to something coarser.
//
// `CGPoint`, `CGSize` and `CGRect` are deliberately absent: `FLLayoutEquatable` refines `Hashable`, and
// their `Hashable` conformances are iOS 18+. See issue #11.

// MARK: - Scalars

extension Bool: FLLayoutEquatable {}
extension String: FLLayoutEquatable {}
extension Character: FLLayoutEquatable {}
extension Int: FLLayoutEquatable {}
extension Int8: FLLayoutEquatable {}
extension Int16: FLLayoutEquatable {}
extension Int32: FLLayoutEquatable {}
extension Int64: FLLayoutEquatable {}
extension UInt: FLLayoutEquatable {}
extension UInt8: FLLayoutEquatable {}
extension UInt16: FLLayoutEquatable {}
extension UInt32: FLLayoutEquatable {}
extension UInt64: FLLayoutEquatable {}
extension Double: FLLayoutEquatable {}
extension Float: FLLayoutEquatable {}
extension CGFloat: FLLayoutEquatable {}

// MARK: - Foundation

extension UUID: FLLayoutEquatable {}
extension Date: FLLayoutEquatable {}
extension URL: FLLayoutEquatable {}
extension Data: FLLayoutEquatable {}
/// Their `==` includes attributes, `.foregroundColor` among them, so a colour baked into stored
/// attributed text is layout-affecting where a colour applied with `.foregroundColor(_:)` is not.
extension AttributedString: FLLayoutEquatable {}
extension NSAttributedString: FLLayoutEquatable {}

// MARK: - UIKit

extension UIColor: FLLayoutEquatable {}
extension UIFont: FLLayoutEquatable {}
extension UIImage: FLLayoutEquatable {}

// MARK: - Containers

extension Optional: FLLayoutEquatable where Wrapped: FLLayoutEquatable {}
extension Array: FLLayoutEquatable where Element: FLLayoutEquatable {}
extension Set: FLLayoutEquatable where Element: FLLayoutEquatable {}
extension Dictionary: FLLayoutEquatable where Key: FLLayoutEquatable, Value: FLLayoutEquatable {}
