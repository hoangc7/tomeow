// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Finit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Finit",
            path: "Sources/Finit",
            swiftSettings: [.unsafeFlags(["-Osize"])],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
