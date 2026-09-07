import Foundation
import os

/// Raises a purple runtime issue in Xcode — the report a `precondition` would make, for a mistake the
/// caller can still recover from at runtime. Debug builds only.
enum FLRuntimeIssue {
    private static let log = OSLog(subsystem: "com.apple.runtime-issues", category: "FrameLayout")

    static func report(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.fault, dso: #dsohandle, log: log, "%{public}@", message())
        #endif
    }
}
