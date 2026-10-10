// swift-tools-version: 6.2
import PackageDescription

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
            exclude: ["Tests", "docs", "videos", "brag-output", "script", "iActivity.app",
                      "iActivity.dmg", "Info.plist", "README.md", "build_and_package.sh", "icon.png"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "iActivityTests",
            dependencies: ["iActivity"],
            path: "Tests/iActivityTests"
        )
    ]
)
