// swift-tools-version: 6.2
import PackageDescription

// The app itself is built, signed and distributed from iActivity.xcodeproj. This package compiles
// the same sources so `swift test` runs the test suite without Xcode.
let package = Package(
    name: "iActivity",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "iActivity", targets: ["iActivity"])
    ],
    targets: [
        .executableTarget(
            name: "iActivity",
            path: ".",
            exclude: ["Tests", "docs", "videos", "script", "iActivity.app", "iActivity.xcodeproj",
                      "iActivity.dmg", "build", "packaging", "Resources", "Info.plist", "README.md", "PRIVACY.md",
                      "build_and_package.sh", "icon.png"]
        ),
        .testTarget(
            name: "iActivityTests",
            dependencies: ["iActivity"],
            path: "Tests/iActivityTests"
        )
    ]
)
