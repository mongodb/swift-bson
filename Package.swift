// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "swift-bson",
    products: [
        .library(name: "BSON", targets: ["BSON"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.16.0"))
    ],
    targets: [
        .target(name: "BSON", dependencies: ["NIO"]),
        .testTarget(name: "BSONTests", dependencies: ["BSON"])
    ]
)
