// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DashboardKit",
    platforms: [
        .macOS(.v14),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "DashboardKit",
            targets: ["DashboardKit"]
        ),
        .library(
            name: "d8aTvCore",
            targets: ["d8aTvCore"]
        ),
        .executable(
            name: "splunk-dashboard",
            targets: ["SplunkDashboardCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "DashboardKit",
            dependencies: [],
            resources: [
                .process("CoreData/DashboardModel.xcdatamodeld")
            ]
        ),
        .target(
            name: "d8aTvCore",
            dependencies: [],
            resources: [
                .process("SplunkConfiguration.plist")
            ]
        ),
        .executableTarget(
            name: "SplunkDashboardCLI",
            dependencies: [
                "DashboardKit",
                "d8aTvCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "DashboardKitTests",
            dependencies: ["DashboardKit"]
        ),
    ]
)
