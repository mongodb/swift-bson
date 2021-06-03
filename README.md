# Swift BSON

![swift-bson-logo](etc/swiftBSON.png)

The official MongoDB BSON implementation in Swift!

## Index

- [Bugs/Feature Requests](#bugs--feature-requests)
- [Installation](#installation)
- [Example Usage](#example-usage)
  - [Work With and Modify Documents](#work-with-and-modify-documents)
- [Development Instructions](#development-instructions)

## Bugs / Feature Requests

Think you've found a bug? Want to see a new feature in `swift-bson`? Please open a case in our issue management tool, JIRA:

1. Create an account and login: [jira.mongodb.org](https://jira.mongodb.org)
2. Navigate to the SWIFT project: [jira.mongodb.org/browse/SWIFT](https://jira.mongodb.org/browse/SWIFT)
3. Click **Create Issue** - Please provide as much information as possible about the issue and how to reproduce it.

Bug reports in JIRA for all driver projects (i.e. NODE, PYTHON, CSHARP, JAVA) and the Core Server (i.e. SERVER) project are **public**.

## Installation

The library supports use with Swift 5.1+. The minimum macOS version required to build the library is 10.14. The library is tested in continuous integration against macOS 10.14, Ubuntu 16.04, and Ubuntu 18.04.

Installation is supported via [Swift Package Manager](https://swift.org/package-manager/).

### Install BSON

To install the library, add the package as a dependency in your project's `Package.swift` file:

```swift
// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mongodb/swift-bson", .upToNextMajor(from: "3.0.1"))
    ],
    targets: [
        .target(name: "MyTarget", dependencies: ["SwiftBSON"])
    ]
)
```

## Example Usage

### Work With and Modify Documents

```swift
import SwiftBSON

var doc: BSONDocument = ["a": 1, "b": 2, "c": 3]

print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3}`
print(doc["a", default: "Not Found!"]) // prints `.int64(1)`

// Set a new value
doc["d"] = 4
print(doc) // prints `{"a" : 1, "b" : 2, "c" : 3, "d" : 4}`

// Using functional methods like map, filter:
let evensDoc = doc.filter { elem in
    guard let value = elem.value.asInt() else {
        return false
    }
    return value % 2 == 0
}
print(evensDoc) // prints `{ "b" : 2, "d" : 4 }`

let doubled = doc.map { elem -> Int in
    guard case let value = .int64(value) else {
        return 0
    }

    return Int(value * 2)
}
print(doubled) // prints `[2, 4, 6, 8]`
```

Note that `BSONDocument` conforms to `Collection`, so useful methods from [`Sequence`](https://developer.apple.com/documentation/swift/sequence) and [`Collection`](https://developer.apple.com/documentation/swift/collection) are all available. However, runtime guarantees are not yet met for many of these methods.

## Development Instructions

See our [development guide](https://github.com/mongodb/mongo-swift-driver/blob/main/Guides/Development.md) for the MongoDB driver to get started.
To run the tests for the BSON library you can make use of the Makefile and run: `make test-pretty` (uses `xcpretty` to change the output format) or just `make test` (for environments without ruby).

## Note

This repository previously contained Swift bindings for libbson, the MongoDB C driver's BSON library. Those bindings are still available under the 2.1.0 tag. Major version 3.0 and up will be used for the BSON library.
