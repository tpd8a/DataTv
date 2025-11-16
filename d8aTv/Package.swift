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
    ],
    targets: [
        .target(
            name: "DashboardKit",
            dependencies: [],
            resources: [
                .process("CoreData/DashboardModel.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "DashboardKitTests",
            dependencies: ["DashboardKit"]
        ),
    ]
)
