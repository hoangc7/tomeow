// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Tomeow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tomeow",
            path: "Sources/Tomeow",
            swiftSettings: [.unsafeFlags(["-Osize"])],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
