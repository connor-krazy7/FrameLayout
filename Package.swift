// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FrameLayout",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FrameLayout", targets: ["FrameLayout"]),
    ],
    targets: [
        .target(
            name: "FrameLayout",
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
