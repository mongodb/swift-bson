import Foundation
import NIO

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct Document {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSON)

    private var _buffer: ByteBuffer

    /// An unordered set containing the keys in this document.
    private var keySet: Set<String>

    internal init(_ elements: [BSON]) { fatalError("Unimplemented") }

    internal init(keyValuePairs: [(String, BSON)]) { fatalError("Unimplemented") }

    /// Initializes a new, empty `Document`.
    public init() { fatalError("Unimplemented") }

    /**
     * Initializes a new `Document` from the provided BSON data.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: Data) throws { fatalError("Unimplemented") }

    /**
     * Initializes a new `Document` from the provided BSON data.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: ByteBuffer) throws { fatalError("Unimplemented") }

    /// The keys in this `Document`.
    public var keys: [String] { fatalError("Unimplemented") }

    /// The values in this `Document`.
    public var values: [BSON] { fatalError("Unimplemented") }

    /// The number of (key, value) pairs stored at the top level of this document.
    public var count: Int { fatalError("Unimplemented") }

    /// A copy of the `ByteBuffer` backing this document, containing raw BSON data. As `ByteBuffer`s implement
    /// copy-on-write, this copy will share byte storage with this document until either the document or the returned
    /// buffer is mutated.
    public var buffer: ByteBuffer { fatalError("Unimplemented") }

    /// Returns a `Data` containing a copy of the raw BSON data backing this document.
    public func toData() -> Data { fatalError("Unimplemented") }

    /// Returns a `Boolean` indicating whether this `Document` contains the provided key.
    public func hasKey(_ key: String) -> Bool { fatalError("Unimplemented") }

    /**
     * Allows getting and setting values on the document via subscript syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     *  ```
     * A nil return value indicates that the key does not exist in the  `Document`. A true BSON null is returned as
     * `BSON.null`.
     */
    public subscript(key: String) -> BSON? {
        get { fatalError("Unimplemented") }
        set { fatalError("Unimplemented") }
    }

    /**
     * Looks up the specified key in the document and returns its corresponding value, or returns `defaultValue` if the
     * key is not present.
     *
     * For example:
     *  ```
     *  let d: Document = ["hello": "world"]
     *  print(d["hello", default: "foo"]) // prints "world"
     *  print(d["a", default: "foo"]) // prints "foo"
     *  ```
     */
    public subscript(key: String, default defaultValue: @autoclosure () -> BSON) -> BSON {
        fatalError("Unimplemented")
    }

    /**
     * Allows getting and setting values on the document using dot-notation syntax.
     * For example:
     *  ```
     *  let d = Document()
     *  d.a = 1
     *  print(d.a) // prints 1
     *  ```
     * A nil return value indicates that the key does not exist in the `Document`.
     * A true BSON null is returned as `BSON.null`.
     */
    public subscript(dynamicMember member: String) -> BSON? {
        get { fatalError("Unimplemented") }
        set { fatalError("Unimplemented") }
    }
}

/// An extension of `Document` to add the capability to be initialized with a dictionary literal.
extension Document: ExpressibleByDictionaryLiteral {
    /**
     * Initializes a `Document` using a dictionary literal where the keys are `Strings` and the values are `BSON`s.
     * For example:
     * `d: Document = ["a" : 1 ]`
     *
     * - Parameters:
     *   - dictionaryLiteral: a [String: BSON]
     *
     * - Returns: a new `Document`
     */
    public init(dictionaryLiteral keyValuePairs: (String, BSON)...) {
        fatalError("Unimplemented")
    }
}

extension Document: Hashable {
    public func hash(into hasher: inout Hasher) {
        fatalError("Unimplemented")
    }
}

extension Document: Equatable {
    public static func == (lhs: Document, rhs: Document) -> Bool {
        fatalError("Unimplemented")
    }
}

extension Document: BSONValue {
    var bsonType: BSONType { fatalError("Unimplemented") }

    var bson: BSON { fatalError("Unimplemented") }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        fatalError("Unimplemented")
    }

    func write(to buffer: inout ByteBuffer) throws {
        fatalError("Unimplemented")
    }
}
