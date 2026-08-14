// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ChromeRail",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ChromeRailCore", targets: ["ChromeRailCore"]),
        .executable(name: "ChromeRail", targets: ["ChromeRail"]),
        .executable(name: "ChromeRailChecks", targets: ["ChromeRailChecks"]),
    ],
    targets: [
        .target(name: "ChromeRailCore"),
        .executableTarget(
            name: "ChromeRail",
            dependencies: ["ChromeRailCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(name: "ChromeRailChecks", dependencies: ["ChromeRailCore"]),
    ],
    swiftLanguageModes: [.v5]
)
