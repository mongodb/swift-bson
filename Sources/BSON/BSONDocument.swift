import Foundation
import NIO

/// This shared allocator instance should be used for all underlying `ByteBuffer` creation.
internal let BSON_ALLOCATOR = ByteBufferAllocator()
/// Maximum BSON document size in bytes
internal let BSON_MAX_SIZE = 0x1000000
/// Minimum BSON document size in bytes
internal let BSON_MIN_SIZE = 5

/// A struct representing the BSON document type.
@dynamicMemberLookup
public struct BSONDocument {
    /// The element type of a document: a tuple containing an individual key-value pair.
    public typealias KeyValuePair = (key: String, value: BSON)

    internal var _buffer: ByteBuffer

    internal var byteLength: Int {
        get {
            guard let byteLength = self._buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
                fatalError("Cannot read byteLength of BSON from buffer")
            }
            return Int(byteLength)
        }
        set {
            self._buffer.setInteger(Int32(newValue), at: 0, endianness: .little, as: Int32.self)
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

        self._buffer = BSON_ALLOCATOR.buffer(capacity: 0)

        guard !self.keySet.isEmpty else {
            self = BSONDocument()
            return
        }

        let start = self._buffer.writerIndex

        // reserve space for our byteLength that will be calculated
        self._buffer.writeInteger(0, endianness: .little, as: Int32.self)

        for element in keyValuePairs {
            BSONDocument.append(element: element, to: &self._buffer)
        }
        // BSON null terminator
        self._buffer.writeInteger(0, as: UInt8.self)

        guard let byteLength = Int32(exactly: self._buffer.writerIndex - start) else {
            fatalError("Data is \(self._buffer.writerIndex - start) bytes, "
                + "but maximum allowed BSON document size is \(Int32.max) bytes")
        }
        // Set byteLength in reserved space
        self._buffer.setInteger(byteLength, at: 0, endianness: .little, as: Int32.self)
    }

    /// Initializes a new, empty `BSONDocument`.
    public init() {
        self.keySet = Set()
        self._buffer = BSON_ALLOCATOR.buffer(capacity: 0)
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
        var buffer = BSON_ALLOCATOR.buffer(capacity: bson.count)
        buffer.writeBytes(bson)
        self = try BSONDocument(fromBSON: buffer)
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
        try BSONDocument.validate(bson)
        self = BSONDocument(fromUnsafeBSON: bson)
    }

    internal init(fromUnsafeBSON bson: ByteBuffer) {
        self.keySet = Set()
        self._buffer = bson
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
    public var buffer: ByteBuffer { self._buffer }

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
        set {
            do {
                try self.set(key: key, of: newValue)
            } catch {
                fatalError("\(error)")
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
    internal mutating func set(key: String, of value: BSON?) throws {
        if !self.keySet.contains(key), let value = value {
            // appending new key
            self.keySet.insert(key)
            self._buffer.moveWriterIndex(to: self.byteLength - 1) // setup to overwrite null terminator
            let size = BSONDocument.append(element: (key, value), to: &self._buffer)
            self._buffer.writeInteger(0, endianness: .little, as: UInt8.self) // add back in our null terminator
            self.byteLength += size
            return
        }

        guard value != nil || self.keySet.contains(key) else {
            // no-op: trying to delete a key that doesn't exist
            return
        }

        var iter = BSONDocumentIterator(over: self._buffer)

        guard let (start, end) = iter.findByteRange(for: key) else {
            throw BSONError.InternalError(message: "Cannot find \(key) to delete")
        }

        var newBuffer = BSON_ALLOCATOR.buffer(capacity: 0)

        guard
            let prefix = self._buffer.getBytes(at: 0, length: start),
            let suffix = self._buffer.getBytes(at: end, length: self.byteLength - end)
        else {
            throw BSONError.InternalError(
                message: "Cannot slice buffer from " +
                    "0 to len \(start) and from \(end) to len \(self.byteLength - end) : \(self._buffer)"
            )
        }

        newBuffer.writeBytes(prefix)

        var newSize = self.byteLength - (end - start)
        if let value = value {
            // Overwriting
            let size = BSONDocument.append(element: (key, value), to: &newBuffer)
            newSize += size

            guard newSize != BSON_MAX_SIZE else {
                throw BSONError.DocumentTooLargeError(value: value.bsonValue, forKey: key)
            }
        } else {
            // Deleting
            self.keySet.remove(key)
        }

        newBuffer.writeBytes(suffix)

        self._buffer = newBuffer
        self.byteLength = newSize
        guard self.byteLength == self._buffer.readableBytes else {
            fatalError("I think the bson is \(self.byteLength) but I can only read \(self._buffer.readableBytes)")
        }
    }

    /// Appends element to underlying BSON bytes, returns the size of the element appended: type + key + value
    @discardableResult
    internal static func append(element: BSONDocument.KeyValuePair, to buffer: inout ByteBuffer) -> Int {
        let writer = buffer.writerIndex
        buffer.writeInteger(element.value.bsonValue.bsonType.rawValue, as: UInt8.self)
        buffer.writeCString(element.key)
        element.value.bsonValue.write(to: &buffer)
        return buffer.writerIndex - writer
    }

    internal static func validate(_ bson: ByteBuffer) throws {
        // Pull apart the underlying binary into [KeyValuePair], should reveal issues
        guard let byteLength = bson.getInteger(at: 0, endianness: .little, as: Int32.self) else {
            throw BSONError.InvalidArgumentError(message: "Validation Failed: Cannot read byteLength")
        }

        guard byteLength >= BSON_MIN_SIZE && byteLength <= BSON_MAX_SIZE else {
            throw BSONError.InvalidArgumentError(message: "Validation Failed: BSON cannot be \(byteLength) bytes long")
        }

        guard byteLength == bson.writerIndex else {
            throw BSONError.InvalidArgumentError(message: "Validation Failed: Cannot read \(byteLength) from bson")
        }

        var iter = BSONDocumentIterator(over: bson)
        // Implicitly validate with iterator
        do {
            while let (_, value) = try iter._next() {
                if let doc = value.documentValue {
                    try BSONDocument.validate(doc.buffer)
                }
            }
        } catch {
            throw BSONError.InvalidArgumentError(message: "Validation failed: \(error)")
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
        var doc = ByteBuffer(self._buffer.readableBytesView)
        buffer.writeBuffer(&doc)
    }
}
