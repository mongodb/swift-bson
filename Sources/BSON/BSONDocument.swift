import Foundation
import NIO

/// This shared allocator instance should be used for all underlying `ByteBuffer` creation.
internal let BSON_ALLOCATOR = ByteBufferAllocator()
/// Maximum BSON document size in bytes
internal let BSON_MAX_SIZE = Int32.max
/// Minimum BSON document size in bytes
internal let BSON_MIN_SIZE = 5

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct BSONDocument {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSON)

    private var storage: BSONDocumentStorage

    internal var byteLength: Int {
        get {
            guard let byteLength = self.storage.buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
                fatalError("Cannot read byteLength of BSON from buffer")
            }
            return Int(byteLength)
        }
        set {
            guard newValue <= Int32.max else {
                fatalError("Cannot cast \(newValue) down to Int32")
            }
            self.storage.buffer.setInteger(Int32(newValue), at: 0, endianness: .little, as: Int32.self)
        }
    }

    /// An unordered set containing the keys in this document.
    internal private(set) var keySet: Set<String>

    internal init(_ elements: [BSON]) {
        self = BSONDocument(keyValuePairs: elements.enumerated().map { i, element in (String(i), element) })
    }

    internal init(keyValuePairs: [(String, BSON)]) {
        self.keySet = Set(keyValuePairs.map { $0.0 })
        guard self.keySet.count == keyValuePairs.count else {
            fatalError("Dictionary \(keyValuePairs) contains duplicate keys")
        }

        self.storage = BSONDocumentStorage()

        guard !self.keySet.isEmpty else {
            self = BSONDocument()
            return
        }

        let start = self.storage.buffer.writerIndex

        // reserve space for our byteLength that will be calculated
        self.storage.buffer.writeInteger(0, endianness: .little, as: Int32.self)

        for (key, value) in keyValuePairs {
            self.storage.append(key: key, value: value)
        }
        // BSON null terminator
        self.storage.buffer.writeInteger(0, as: UInt8.self)

        guard let byteLength = Int32(exactly: self.storage.buffer.writerIndex - start) else {
            fatalError("Data is \(self.storage.buffer.writerIndex - start) bytes, "
                + "but maximum allowed BSON document size is \(Int32.max) bytes")
        }
        // Set byteLength in reserved space
        self.storage.buffer.setInteger(byteLength, at: 0, endianness: .little, as: Int32.self)
    }

    /// Initializes a new, empty `BSONDocument`.
    public init() {
        self.keySet = Set()
        self.storage = BSONDocumentStorage()
        self.storage.buffer.writeInteger(5, endianness: .little, as: Int32.self)
        self.storage.buffer.writeBytes([0])
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
        var buffer = BSON_ALLOCATOR.buffer(capacity: bson.count)
        buffer.writeBytes(bson)
        self = try BSONDocument(fromBSON: buffer)
    }

    /**
     * Initializes a new BSONDocument from the provided BSON data.
     * The buffer must have readableBytes equal to the BSON's leading size indicator.
     *
     * - Throws:
     *   - `InvalidArgumentError` if the data passed is invalid BSON
     *
     * - SeeAlso: http://bsonspec.org/
     */
    public init(fromBSON bson: ByteBuffer) throws {
        let storage = BSONDocumentStorage(bson)
        try storage.validate()
        self = BSONDocument(fromUnsafeBSON: storage)
    }

    private init(fromUnsafeBSON storage: BSONDocumentStorage) {
        self.keySet = Set()
        self.storage = storage
        for (key, _) in self {
            self.keySet.insert(key)
        }
    }

    /// The keys in this `BSONDocument`.
    public var keys: [String] { self.map { key, _ in key } }

    /// The values in this `BSONDocument`.
    public var values: [BSON] { self.map { _, val in val } }

    /// The number of (key, value) pairs stored at the top level of this document.
    public var count: Int { self.keySet.count }

    /// A copy of the `ByteBuffer` backing this document, containing raw BSON data. As `ByteBuffer`s implement
    /// copy-on-write, this copy will share byte storage with this document until either the document or the returned
    /// buffer is mutated.
    public var buffer: ByteBuffer { self.storage.buffer }

    /// Returns a `Data` containing a copy of the raw BSON data backing this document.
    public func toData() -> Data { Data(self.storage.buffer.readableBytesView) }

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
        set {
            // The only time this would crash is document too big error
            do {
                return try self.set(key: key, to: newValue)
            } catch {
                fatalError("Failed to set \(key) to \(String(describing: newValue)): \(error)")
            }
        }
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
        self[key] ?? defaultValue()
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
        set { self[member] = newValue }
    }

    /**
     * Sets a BSON element with the corresponding key
     * if element.value is nil the element is deleted from the BSON
     */
    internal mutating func set(key: String, to value: BSON?) throws {
        if !self.keySet.contains(key) {
            guard let value = value else {
                // no-op: key does not exist and the value is nil
                return
            }
            // appending new key
            self.keySet.insert(key)
            self.storage.buffer.moveWriterIndex(to: self.byteLength - 1) // setup to overwrite null terminator
            let size = self.storage.append(key: key, value: value)
            self.storage.buffer.writeInteger(0, endianness: .little, as: UInt8.self) // add back in our null terminator
            self.byteLength += size
            return
        }

        var iter = BSONDocumentIterator(over: self.storage.buffer)

        guard let range = iter.findByteRange(for: key) else {
            throw BSONError.InternalError(message: "Cannot find \(key) to delete")
        }

        guard
            let prefix = self.storage.buffer.getBytes(at: 0, length: range.startIndex),
            let suffix = self.storage.buffer.getBytes(at: range.endIndex, length: self.byteLength - range.endIndex)
        else {
            throw BSONError.InternalError(
                message: "Cannot slice buffer from " +
                    "0 to len \(range.startIndex) and from \(range.endIndex) " +
                    "to len \(self.byteLength - range.endIndex) : \(self.storage.buffer)"
            )
        }

        var newStorage = BSONDocumentStorage()
        newStorage.buffer.writeBytes(prefix)

        var newSize = self.byteLength - (range.endIndex - range.startIndex)
        if let value = value {
            // Overwriting
            let size = newStorage.append(key: key, value: value)
            newSize += size

            guard newSize <= BSON_MAX_SIZE else {
                throw BSONError.DocumentTooLargeError(value: value.bsonValue, forKey: key)
            }
        } else {
            // Deleting
            self.keySet.remove(key)
        }

        newStorage.buffer.writeBytes(suffix)

        self.storage = newStorage
        self.byteLength = newSize
        guard self.byteLength == self.storage.buffer.readableBytes else {
            fatalError("BSONDocument's encoded byte length is \(self.byteLength) however the" +
                "buffer has \(self.storage.buffer.readableBytes) readable bytes")
        }
    }

    /// Storage management for BSONDocuments.
    /// A wrapper around a ByteBuffer providing various BSONDocument-specific utilities.
    private struct BSONDocumentStorage {
        internal var buffer: ByteBuffer

        /// Create BSONDocumentStorage from ByteBuffer.
        internal init(_ buffer: ByteBuffer) { self.buffer = buffer }

        /// Create BSONDocumentStorage with a 0 capacity buffer.
        internal init() { self.buffer = BSON_ALLOCATOR.buffer(capacity: 0) }

        /// Appends element to underlying BSON bytes, returns the size of the element appended: type + key + value
        @discardableResult internal mutating func append(key: String, value: BSON) -> Int {
            let writer = self.buffer.writerIndex
            self.buffer.writeInteger(value.bsonValue.bsonType.rawValue, as: UInt8.self)
            self.buffer.writeCString(key)
            value.bsonValue.write(to: &self.buffer)
            return self.buffer.writerIndex - writer
        }

        internal func validate() throws {
            // Pull apart the underlying binary into [KeyValuePair], should reveal issues
            guard let byteLength = self.buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
                throw BSONError.InvalidArgumentError(message: "Validation Failed: Cannot read byteLength")
            }

            guard byteLength >= BSON_MIN_SIZE && byteLength <= BSON_MAX_SIZE else {
                throw BSONError.InvalidArgumentError(
                    message: "Validation Failed: BSON cannot be \(byteLength) bytes long"
                )
            }

            guard byteLength == self.buffer.readableBytes else {
                throw BSONError.InvalidArgumentError(
                    message: "BSONDocument's encoded byte length is \(byteLength) however the" +
                        "buffer has \(self.buffer.readableBytes) readable bytes"
                )
            }

            var iter = BSONDocumentIterator(over: self.buffer)
            // Implicitly validate with iterator
            do {
                while let (_, value) = try iter.nextThrowing() {
                    switch value {
                    case let .document(doc):
                        try doc.storage.validate()
                    case let .array(array):
                        for item in array {
                            if let doc = item.documentValue {
                                try doc.storage.validate()
                            }
                        }
                    default:
                        continue
                    }
                }
            }
        }
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
        hasher.combine(self.buffer)
    }
}

extension BSONDocument: Equatable {
    public static func == (lhs: BSONDocument, rhs: BSONDocument) -> Bool {
        lhs.buffer == rhs.buffer
    }
}

extension BSONDocument: BSONValue {
    /*
     * Initializes a `BSONDocument` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for any `BSONDocument`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value does not conform to the `BSONDocument` syntax.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard case let .object(obj) = json else {
            return nil
        }
        var doc: [(String, BSON)] = []
        for (key, val) in obj {
            let bsonValue = try BSON(fromExtJSON: val, keyPath: keyPath + [key])
            doc.append((key, bsonValue))
        }
        self = BSONDocument(keyValuePairs: doc)
    }

    internal static var bsonType: BSONType { .document }

    internal var bson: BSON { .document(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        let reader = buffer.readerIndex
        guard let byteLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Cannot read document byte length")
        }
        buffer.moveReaderIndex(to: reader)
        guard let bytes = buffer.readBytes(length: Int(byteLength)) else {
            throw BSONError.InternalError(message: "Cannot read document contents")
        }
        return .document(try BSONDocument(fromBSON: Data(bytes)))
    }

    internal func write(to buffer: inout ByteBuffer) {
        var doc = ByteBuffer(self.storage.buffer.readableBytesView)
        buffer.writeBuffer(&doc)
    }
}
