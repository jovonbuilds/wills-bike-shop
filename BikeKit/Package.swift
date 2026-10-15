// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BikeKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "BikeKit", targets: ["BikeKit"]),
    ],
    targets: [
        .target(name: "BikeKit"),
        .testTarget(name: "BikeKitTests", dependencies: ["BikeKit"]),
    ],
    swiftLanguageModes: [.v5]
)
