// swift-tools-version: 6.2
import PackageDescription


let package = Package(
    name: "d8aTv",
    
    platforms: [
        .macOS(.v26),
        .tvOS(.v26)
    ],
    products: [
        .library(
            name: "d8aTvCore",
            targets: ["d8aTvCore"]
        ),
        .executable(
            name: "splunk-dashboard",
            targets: ["SplunkDashboardCLI"]
        ),
        .executable(
            name: "dashboard-monitor-mac",
            targets: ["DashboardMonitorApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "d8aTvCore",
            dependencies: [],
            resources: [
                .process("./SplunkConfiguration.plist")
            ]
        ),
        .executableTarget(
            name: "SplunkDashboardCLI",
            dependencies: [
                "d8aTvCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "DashboardMonitorApp",
            dependencies: ["d8aTvCore"],
            swiftSettings: [
                .define("os_macOS")
            ]
        ),
        .testTarget(
            name: "d8aTvTests",
            dependencies: ["d8aTvCore"]
        )
    ]
)
