import Foundation
import NIO

/// This shared allocator instance should be used for all underlying `ByteBuffer` creation.
internal let BSON_ALLOCATOR = ByteBufferAllocator()
/// Maximum BSON document size in bytes
internal let BSON_MAX_SIZE = 16_000_000
/// Minimum BSON document size in bytes
internal let BSON_MIN_SIZE = 5

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct BSONDocument {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSON)

    private var _buffer: ByteBuffer

    internal var size: Int {
        guard let size = self._buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
            fatalError("Cannot read size of BSON from buffer")
        }
        return Int(size)
    }

    /// An unordered set containing the keys in this document.
    private var keySet: Set<String>

    internal init(_ elements: [BSON]) { fatalError("Unimplemented") }

    internal init(keyValuePairs: [(String, BSON)]) {
        self.keySet = Set(keyValuePairs.map { $0.0 })
        guard self.keySet.count == keyValuePairs.count else {
            fatalError("Dictionary \(keyValuePairs) contains duplicate keys")
        }

        self._buffer = BSON_ALLOCATOR.buffer(capacity: 100)

        guard !self.keySet.isEmpty else {
            self = BSONDocument()
            return
        }

        let start = self._buffer.writerIndex

        // reserve space for our size that will be calculated
        self._buffer.writeInteger(0, endianness: .little, as: Int32.self)

        for (key, value) in keyValuePairs {
            self._buffer.writeInteger(value.bsonValue.bsonType.rawValue, as: UInt8.self)
            self._buffer.writeCString(key)
            value.bsonValue.write(to: &self._buffer)
        }
        self._buffer.writeInteger(0, as: UInt8.self)

        guard let size = Int32(exactly: self._buffer.writerIndex - start) else {
            fatalError("Data is \(self._buffer.writerIndex - start) bytes, "
                + "but maximum allowed BSON document size is \(Int32.max) bytes")
        }
        // BSON null terminator
        self._buffer.setInteger(size, at: 0, endianness: .little, as: Int32.self)
    }

    /// Initializes a new, empty `BSONDocument`.
    public init() {
        self.keySet = Set()
        self._buffer = BSON_ALLOCATOR.buffer(capacity: 5)
        self._buffer.writeInteger(5, endianness: .little, as: Int32.self)
        self._buffer.writeBytes([0])
    }

    /**
     * Initializes a new `BSONDocument` from the provided BSON data.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: Data) throws {
        guard BSONDocument.isValidBSON(bson) else {
            throw BSONError.InvalidArgumentError(message: "Found `\([UInt8](bson))` is invalid BSON")
        }
        self = BSONDocument(fromUnsafeBSON: bson)
    }

    internal init(fromUnsafeBSON bson: Data) {
        // trust the incoming format
        self.keySet = Set()
        self._buffer = BSON_ALLOCATOR.buffer(capacity: bson.count)
        self._buffer.writeBytes(bson)
        for (key, _) in self {
            self.keySet.insert(key)
        }
    }

    /**
     * Initializes a new `BSONDocument` from the provided BSON data.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: ByteBuffer) throws {
        if !BSONDocument.isValidBSON(bson) {
            throw BSONError.InternalError(message: "Found \(bson) is invalid BSON")
        }
        self = BSONDocument(fromUnsafeBSON: bson)
    }

    internal init(fromUnsafeBSON bson: ByteBuffer) { fatalError("Unimplemented") }

    /// The keys in this `BSONDocument`.
    public var keys: [String] { self.map { key, _ in key } }

    /// The values in this `BSONDocument`.
    public var values: [BSON] { self.map { _, val in val } }

    /// The number of (key, value) pairs stored at the top level of this document.
    public var count: Int { self.keySet.count }

    /// A copy of the `ByteBuffer` backing this document, containing raw BSON data. As `ByteBuffer`s implement
    /// copy-on-write, this copy will share byte storage with this document until either the document or the returned
    /// buffer is mutated.
    public var buffer: ByteBuffer { ByteBuffer(self._buffer.readableBytesView) }

    /// Returns a `Data` containing a copy of the raw BSON data backing this document.
    public func toData() -> Data { Data(self._buffer.readableBytesView) }

    /// Returns a `Boolean` indicating whether this `BSONDocument` contains the provided key.
    public func hasKey(_ key: String) -> Bool { self.keySet.contains(key) }

    /**
     * Allows getting and setting values on the document via subscript syntax.
     * For example:
     *  ```
     *  let d = BSONDocument()
     *  d["a"] = 1
     *  print(d["a"]) // prints 1
     *  ```
     * A nil return value indicates that the key does not exist in the  `BSONDocument`. A true BSON null is returned as
     * `BSON.null`.
     */
    public subscript(key: String) -> BSON? {
        get {
            for (docKey, value) in self where docKey == key {
                return value
            }
            return nil
        }
        set { fatalError("Unimplemented") }
    }

    /**
     * Looks up the specified key in the document and returns its corresponding value, or returns `defaultValue` if the
     * key is not present.
     *
     * For example:
     *  ```
     *  let d: BSONDocument = ["hello": "world"]
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
     *  let d = BSONDocument()
     *  d.a = 1
     *  print(d.a) // prints 1
     *  ```
     * A nil return value indicates that the key does not exist in the `BSONDocument`.
     * A true BSON null is returned as `BSON.null`.
     */
    public subscript(dynamicMember member: String) -> BSON? {
        get { self[member] }
        set { fatalError("Unimplemented") }
    }

    internal static func isValidBSON(_ bson: Data) -> Bool {
        // Pull apart the underlying binary into [KeyValuePair], should reveal issues
        // TODO(SWIFT-866): Add validation
        true
    }

    internal static func isValidBSON(_ bson: ByteBuffer) -> Bool {
        // Pull apart the underlying binary into [KeyValuePair], should reveal issues
        // TODO(SWIFT-866): Add validation
        true
    }
}

/// An extension of `BSONDocument` to add the capability to be initialized with a dictionary literal.
extension BSONDocument: ExpressibleByDictionaryLiteral {
    /**
     * Initializes a `BSONDocument` using a dictionary literal where the keys are `Strings` and the values are `BSON`s.
     * For example:
     * `d: BSONDocument = ["a" : 1 ]`
     *
     * - Parameters:
     *   - dictionaryLiteral: a [String: BSON]
     *
     * - Returns: a new `BSONDocument`
     */
    public init(dictionaryLiteral keyValuePairs: (String, BSON)...) {
        self.init(keyValuePairs: keyValuePairs)
    }
}

extension BSONDocument: Hashable {
    public func hash(into hasher: inout Hasher) {
        fatalError("Unimplemented")
    }
}

extension BSONDocument: Equatable {
    public static func == (lhs: BSONDocument, rhs: BSONDocument) -> Bool {
        fatalError("Unimplemented")
    }
}

extension BSONDocument: BSONValue {
    static var bsonType: BSONType { fatalError("Unimplemented") }

    var bson: BSON { fatalError("Unimplemented") }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        fatalError("Unimplemented")
    }

    func write(to buffer: inout ByteBuffer) {
        fatalError("Unimplemented")
    }
}
