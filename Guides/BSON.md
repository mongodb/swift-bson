# MongoDB BSON Library
MongoDB stores and transmits data in the form of [BSON](bsonspec.org) documents, and this library be used to work with such documents. The following is an example of some of the functionality provided as part of that:
```swift
// Document construction.
let doc: BSONDocument = [
    "name": "Bob",
    "occupation": "Software Engineer",
    "projects": [
        ["id": 76, "title": "Documentation"]
    ]
]
// Reading from documents.
print(doc["name"]) // .string(Bob)
print(doc["projects"]) // .array([.document({ "id": 76, "title": "Documentation" })])

// Document serialization and deserialization.
struct Person: Codable {
    let name: String
    let occupation: String
}
print(try BSONDecoder().decode(Person.self, from: doc)) // Person(name: "Bob", occupation: "Software Engineer")
print(try BSONEncoder().encode(Person(name: "Ted", occupation: "Janitor"))) // { "name": "Ted", "occupation": "Janitor" }
```

## BSON values
BSON values have many possible types, ranging from simple 32-bit integers to documents which store more BSON values themselves. To accurately model this, the driver defines the `BSON` enum, which has a distinct case for each BSON type. For the more simple cases such as BSON null, the case has no associated value. For the more complex ones, such as documents, a separate type is defined that the case wraps. Where possible, the enum case will wrap the standard library/Foundation equivalent (e.g. `Double`, `String`, `Date`)
```swift
public enum BSON {
    case .null,
    case .document(BSONDocument)
    case .double(Double)
    case .datetime(Date)
    case .string(String)
    // ...rest of the cases...
}
```
### Initializing a `BSON`
This enum can be instantiated directly like any other enum in the Swift language, but it also conforms to a number of `ExpressibleByXLiteral` protocols, meaning it can be instantiated directly from numeric, string, boolean, dictionary, and array literals.
```swift
let int: BSON = 5 // .int64(5) on 64-bit systems
let double: BSON = 5.5 // .double(5.5)
let string: BSON = "hello world" // .string("hello world")
let bool: BSON = false // .bool(false)
let document: BSON = ["x": 5, "y": true, "z": ["x": 1]] // .document({ "x": 5, "y": true, "z": { "x": 1 } })
let array: BSON = ["1", true, 5.5] // .array([.string("1"), .bool(true), .double(5.5)])
```
All other cases must be initialized directly:
```swift
let date = BSON.datetime(Date())
let objectId = BSON.objectID()
// ...rest of cases...
```
### Unwrapping a `BSON`
To get a `BSON` value as a specific type, you can use `switch` or `if/guard case let` like any other enum in Swift:
```swift
func foo(x: BSON, y: BSON) {
    switch x {
    case let .int32(int32):
        print("got an Int32: \(int32)")
    case let .objectID(oid):
        print("got an objectId: \(oid.hex)")
    default:
        print("got something else")
    }
    guard case let .double(d) = y else {
        print("y must be a double")
        return
    }
    print(d * d)
}
```
While these methods are good for branching, sometimes it is useful to get just the value (e.g. for optional chaining, passing as a parameter, or returning from a function). For those cases, `BSON` has computed properties for each case that wraps a type. These properties will return `nil` unless the underlying BSON value is an exact match to the return type of the property.
```swift
func foo(x: BSON) -> [BSONDocument] {
    guard let documents = x.arrayValue?.compactMap({ $0.documentValue }) else {
        print("x is not an array")
        return []
    }
    return documents
}
print(BSON.int64(5).int32Value) // nil
print(BSON.int32(5).int32Value) // Int32(5)
print(BSON.double(5).int64Value) // nil
print(BSON.double(5).doubleValue) // Double(5.0)
```
### Converting a `BSON`
In some cases, especially when dealing with numbers, it may make sense to coerce a `BSON`'s wrapped value into a similar one. For those situations, there are several conversion methods defined on `BSON` that will unwrap the underlying value and attempt to convert it to the desired type. If that conversion would be lossless, a non-`nil` value is returned. 
```swift
func foo(x: BSON, y: BSON) {
    guard let x = x.toInt(), let y = y.toInt() else {
        print("provide two integer types")
        return
    }
    print(x + y)
}
foo(x: 5, y: 5.0) // 10
foo(x: 5, y: 5) // 10
foo(x: 5.0, y: 5.0) // 10
foo(x: .int32(5), y: .int64(5)) // 10
foo(x: 5.01, y: 5) // error
```
There are similar conversion methods for the other types, namely `toInt32()`, `toDouble()`, `toInt64()`, and `toDecimal128()`.

### Using a `BSON` value
`BSON` conforms to a number of useful Foundation protocols, namely `Codable`, `Equatable`, and `Hashable`. This allows them to be compared, encoded/decoded, and used as keys in maps:
```swift
// Codable conformance synthesized by compiler.
struct X: Codable {
    let _id: BSON
}
// Equatable
let x: BSON = "5"
let y: BSON = 5
let z: BSON = .string("5")
print(x == y) // false
print(x == z) // true
// Hashable
let map: [BSON: String] = [
    "x": "string",
    false: "bool",
    [1, 2, 3]: "array",
    .objectID(): "oid",
    .null: "null",
    .maxKey: "maxKey"
]
```
## Documents
BSON documents are the top-level structures that contain the aforementioned BSON values, and they are also BSON values themselves. The driver defines the `BSONDocument` struct to model this specific BSON type.
### Initializing documents
Like `BSON`, `BSONDocument` can also be initialized by a dictionary literal. The elements within the literal must be `BSON`s, so further literals can be embedded within the top level literal definition:
```swift
let x: BSONDocument = [
    "x": 5,
    "y": 5.5,
    "z": [
        "a": [1, true, .datetime(Date())]
    ]
]
```
Documents can also be initialized directly by passing in a `Data` containing raw BSON bytes:
```swift
try BSONDocument(fromBSON: Data(...))
```
Documents may be initialized from an [extended JSON](https://docs.mongodb.com/manual/reference/mongodb-extended-json/) string as well:
```swift
try BSONDocument(fromJSON: "{ \"x\": true }") // { "x": true }
try BSONDocument(fromJSON: "{ x: false }}}") // error
```
### Using documents
Documents define the interface in which an application communicates with a MongoDB deployment. For that reason, `BSONDocument` has been fitted with functionality to make it both powerful and ergonomic to use for developers.
#### Reading / writing to `BSONDocument`
`BSONDocument` conforms to [`Collection`](https://developer.apple.com/documentation/swift/collection), which allows for easy reading and writing of elements via the subscript operator. On `BSONDocument`, this operator returns and accepts a `BSON?`:
```swift
var doc: BSONDocument = ["x": 1]
print(doc["x"]) // .int64(1)
doc["x"] = ["y": .null]
print(doc["x"]) // .document({ "y": null })
doc["x"] = nil
print(doc["x"]) // nil
print(doc) // { }
```
`BSONDocument` also has the `@dynamicMemberLookup` attribute, meaning it's values can be accessed directly as if they were properties on `BSONDocument`:
```swift
var doc: BSONDocument = ["x": 1]
print(doc.x) // .int64(1)
doc.x = ["y": .null]
print(doc.x) // .document({ "y": null })
doc.x = nil
print(doc.x) // nil
print(doc) // { }
```
`BSONDocument` also conforms to [`Sequence`](https://developer.apple.com/documentation/swift/sequence), which allows it to be iterated over:
```swift
for (k, v) in doc { 
    print("\(k) = \(v)")
}
```
Conforming to `Sequence` also gives a number of useful methods from the functional programming world, such as `map` or `allSatisfy`:
```swift
let allEvens = doc.allSatisfy { _, v in v.toInt() ?? 1 % 2 == 0 }
let squares = doc.map { k, v in v.toInt()! * v.toInt()! }
```
See the documentation for `Sequence` for a full list of methods that `BSONDocument` implements as part of this.

In addition to those protocol conformances, there are a few one-off helpers implemented on `BSONDocument` such as `filter` (that returns a `BSONDocument`) and `mapValues` (also returns a `BSONDocument`):
```swift
let doc: BSONDocument = ["_id": .objectID(), "numCats": 2, "numDollars": 1.56, "numPhones": 1]
doc.filter { k, v in k.contains("num") && v.toInt() != nil }.mapValues { v in .int64(v.toInt64()! + 5) } // { "numCats": 7, "numPhones": 6 }
```
See the driver's documentation for a full listing of `BSONDocument`'s public API.
## `Codable` and `BSONDocument`
[`Codable`](https://developer.apple.com/documentation/swift/codable) is a protocol defined in Foundation that allows for ergonomic conversion between various serialization schemes and Swift data types. As part of the BSON library, MongoSwift defines both `BSONEncoder` and `BSONDecoder` to facilitate this serialization and deserialization to and from BSON via `Codable`. This allows applications to work with BSON documents in a type-safe way, and it removes much of the runtime key presence and type checking required when working with raw documents. It is reccommended that users leverage `Codable` wherever possible in their applications that use the driver instead of accessing documents directly. 

For example, here is an function written using raw documents:
```swift
let person: BSONDocument = [
    "name": "Bob",
    "occupation": "Software Engineer",
    "projects": [
        ["id": 1, "title": "Server Side Swift Application"],
        ["id": 76, "title": "Write documentation"],
    ]
]

func prettyPrint(doc: BSONDocument) {
    guard let name = doc["name"]?.stringValue else {
        print("missing name")
        return
    }
    print("Name: \(name)")
    guard let occupation = doc["occupation"]?.stringValue else {
        print("missing occupation")
        return
    }
    print("Occupation: \(occupation)")
    guard let projects = doc["projects"]?.arrayValue?.compactMap({ $0.documentValue }) else {
        print("missing projects")
        return
    }
    print("Projects:")
    for project in projects {
        guard let title = project["title"] else {
            print("missing title")
            return
        }
        print(title)
    }
}
```
Due to the flexible nature of `BSONDocument`, a number of checks have to be put into the body of the function. This clutters the actual function's logic and requires a lot of boilerplate code. Now, consider the following function which does the same thing but is written leveraging `Codable`:
```swift
struct Project: Codable {
    let id: BSON
    let title: String
}

struct Person: Codable {
    let name: String
    let occupation: String
    let projects: [Project]
}

func prettyPrint(doc: BSONDocument) throws {
    let person = try BSONDecoder().decode(Person.self, from: doc)
    print("Name: \(person.name)")
    print("Occupation: \(person.occupation)")
    print("Projects:")
    for project in person.projects {
        print(project.title)
    }
}
```
In this version, the definition of the data type and the logic of the function are defined completely separately, and it leads to far more readable and concise versions of both. 
