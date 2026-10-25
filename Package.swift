// swift-tools-version: 6.2

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "imessage-to-notes",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "1.1.1"),
    ],
    targets: [
        .target(
            name: "ImessageToNotesCore",
            swiftSettings: swiftSettings,
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "imessage-to-notes",
            dependencies: [
                "ImessageToNotesCore",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ImessageToNotesCoreTests",
            dependencies: ["ImessageToNotesCore"],
            swiftSettings: swiftSettings
        ),
    ]
)
