import Foundation

public extension Optional {
    func or(_ fallbackValue: @autoclosure () -> Wrapped) -> Wrapped {
        self ?? fallbackValue()
    }

    func or(_ fallbackValue: @autoclosure () -> Wrapped?) -> Wrapped? {
        self ?? fallbackValue()
    }
}

public extension Optional where Wrapped == String {
    var orEmpty: Wrapped { or("") }
}
