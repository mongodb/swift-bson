// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "swift-bson",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v11)
    ],
    products: [
        .library(name: "SwiftBSON", targets: ["SwiftBSON"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.16.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-json", .upToNextMinor(from: "0.6.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-base64", .upToNextMinor(from: "0.5.0")),
        .package(url: "https://github.com/Quick/Nimble.git", .upToNextMajor(from: "8.0.0"))
    ],
    targets: [
        .target(name: "SwiftBSON", dependencies: ["NIO", "ExtrasJSON", "ExtrasBase64"]),
        .testTarget(name: "SwiftBSONTests", dependencies: ["SwiftBSON", "Nimble", "ExtrasJSON"])
    ]
)
