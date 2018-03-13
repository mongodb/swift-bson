// swift-tools-version:4.0
import PackageDescription
let package = Package(
    name: "libbson",
    pkgConfig: "libbson-1.0",
    providers: [
        .brew(["mongo-c-driver"]),
        .apt(["libbson-dev"])
    ],
    products: [
        .library(name: "libbson", targets: ["libbson"])
    ]
)
