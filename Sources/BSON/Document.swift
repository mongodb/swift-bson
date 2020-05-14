import Foundation
import NIO

private let BSON_ALLOCATOR = ByteBufferAllocator()

extension ByteBuffer {
    @discardableResult
    internal mutating func writeCString(_ string: String) -> Int {
        let written = self.writeString(string + "\0")
        return written
    }

    internal mutating func readCString() throws -> String? {
        var string = ""
        for _ in 0..<0xFFFFFE {
            if let b = self.readBytes(length: 1) {
                if b[0] == 0 {
                    return string
                }
                // swiftlint:disable:next force_unwrapping
                string += String(bytes: b, encoding: .utf8)!
            }
        }
        throw InternalError(message: "C String too long")
    }
}

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct Document {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSON)

    private var _buffer: ByteBuffer

    /// An unordered set containing the keys in this document.
    private var keySet: Set<String>

    internal init(_ elements: [BSON]) { fatalError("Unimplemented") }

    internal init(keyValuePairs: [(String, BSON)]) {
        self.keySet = Set()
        self._buffer = BSON_ALLOCATOR.buffer(capacity: 100)

        var size: Int32 = 0
        // reserve space for our size to be calculated
        self._buffer.writeInteger(0, endianness: .little, as: Int32.self)

        for (key, bson) in keyValuePairs {
            self.keySet.insert(key)
            size += Int32(self._buffer.writeInteger(UInt8(bson.bsonValue.bsonType.rawValue), as: UInt8.self))
            size += Int32(self._buffer.writeCString(key))
            let indexBefore = self._buffer.writerIndex
            // swiftlint:disable:next force_try
            try! bson.bsonValue.write(to: &self._buffer)
            size += Int32(self._buffer.writerIndex - indexBefore)
        }
        self._buffer.writeInteger(0, as: UInt8.self)
        size += 1

        self._buffer.setInteger(size, at: 0, endianness: .little, as: Int32.self)
    }

    /// Initializes a new, empty `Document`.
    public init() {
        self.keySet = Set()
        self._buffer = BSON_ALLOCATOR.buffer(capacity: 5)
        self._buffer.writeInteger(5, endianness: .little, as: Int32.self)
        self._buffer.writeBytes([0])
    }

    /**
     * Initializes a new `Document` from the provided BSON data. If validate is `true` (the default), validates that
     * the data is specification-compliant BSON.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: Data, validate: Bool = true) throws { fatalError("Unimplemented") }

    /**
     * Initializes a new `Document` from the provided BSON data. If validate is `true` (the default), validates that
     * the data is specification-compliant BSON.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: ByteBuffer, validate: Bool = true) throws { fatalError("Unimplemented") }

    /// The keys in this `Document`.
    public var keys: [String] { self.map { key, _ in key } }

    /// The values in this `Document`.
    public var values: [BSON] { self.map { _, val in val } }

    /// The number of (key, value) pairs stored at the top level of this document.
    public var count: Int { self.keySet.count }

    /// A copy of the `ByteBuffer` backing this document, containing raw BSON data. As `ByteBuffer`s implement
    /// copy-on-write, this copy will share byte storage with this document until either the document or the returned
    /// buffer is mutated.
    public var buffer: ByteBuffer { ByteBuffer(self._buffer.readableBytesView) }

    /// Returns a `Data` containing a copy of the raw BSON data backing this document.
    public func toData() -> Data { Data(self._buffer.readableBytesView) }

    /// Returns a `Boolean` indicating whether this `Document` contains the provided key.
    public func hasKey(_ key: String) -> Bool { self.keySet.contains(key) }

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
        get {
            for (key, value) in self where key == member {
                return value
            }
            return nil
        }
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
        self.init(keyValuePairs: keyValuePairs)
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
