import ExtrasJSON
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
        // Set encodedLength in reserved space
        self.storage.encodedLength = Int(byteLength)
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
        let keys = try storage.validateAndRetrieveKeys()
        self = BSONDocument(fromUnsafeBSON: storage, keys: keys)
    }

    internal init(fromUnsafeBSON storage: BSONDocumentStorage, keys: Set<String>) {
        self.storage = storage
        self.keySet = keys
    }

    /**
     * Constructs a new `BSONDocument` from the provided JSON text.
     *
     * - Parameters:
     *   - fromJSON: a JSON document as `Data` to parse into a `BSONDocument`
     *
     * - Returns: the parsed `BSONDocument`
     *
     * - Throws: `DecodingError` if `json` is a partial match or is malformed.
     */
    public init(fromJSON json: Data) throws {
        let decoder = ExtendedJSONDecoder()
        self = try decoder.decode(BSONDocument.self, from: json)
    }

    /// Convenience initializer for constructing a `BSONDocument` from a `String`.
    /// - Throws: `DecodingError` if `json` is a partial match or is malformed.
    public init(fromJSON json: String) throws {
        // `String`s are Unicode under the hood so force unwrap always succeeds.
        // see https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        try self.init(fromJSON: json.data(using: .utf8)!) // swiftlint:disable:this force_unwrapping
    }

    /// Returns the relaxed extended JSON representation of this `BSONDocument`.
    /// On error, an empty string will be returned.
    public func toExtendedJSONString() -> String {
        let encoder = ExtendedJSONEncoder()
        guard let encoded = try? encoder.encode(self) else {
            return ""
        }
        return String(data: encoded, encoding: .utf8) ?? ""
    }

    /// Returns the canonical extended JSON representation of this `BSONDocument`.
    /// On error, an empty string will be returned.
    public func toCanonicalExtendedJSONString() -> String {
        let encoder = ExtendedJSONEncoder()
        encoder.mode = .canonical
        guard let encoded = try? encoder.encode(self) else {
            return ""
        }
        return String(data: encoded, encoding: .utf8) ?? ""
    }

    /// The keys in this `BSONDocument`.
    public var keys: [String] {
        do {
            return try BSONDocumentIterator.getKeys(from: self.storage.buffer)
        } catch {
            fatalError("Failed to retrieve keys for document")
        }
    }

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
            do {
                return try BSONDocumentIterator.find(key: key, in: self)?.value
            } catch {
                fatalError("Error looking up key \(key) in document: \(error)")
            }
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
     * Returns a copy of this document with an `_id` element prepended. If the document already contains an `_id`,
     * returns the document as-is.
     * - Throws: `BSONError.DocumentTooLargeError` if adding the `_id` would make the document exceed the maximum
     *           allowed size for a document.
     * - SeeAlso: https://docs.mongodb.com/manual/core/document/#the-id-field
     */
    public func withID() throws -> BSONDocument {
        guard !self.keySet.contains("_id") else {
            return self
        }

        var newStorage = BSONDocumentStorage()
        // placeholder for length
        newStorage.buffer.writeInteger(0, endianness: .little, as: Int32.self)
        var newSize = self.storage.encodedLength

        let _id = BSON.objectID()
        newSize += newStorage.append(key: "_id", value: _id)

        guard newSize <= BSON_MAX_SIZE else {
            throw BSONError.DocumentTooLargeError(value: _id.bsonValue, forKey: "_id")
        }

        guard let suffix = self.storage.buffer.getBytes(at: 4, length: self.storage.encodedLength - 4) else {
            throw BSONError.InternalError(
                message: "Failed to slice buffer from 4 to \(self.storage.encodedLength): \(self.storage.buffer)"
            )
        }
        newStorage.buffer.writeBytes(suffix)

        var newKeys = self.keySet
        newKeys.insert("_id")
        var document = BSONDocument(fromUnsafeBSON: newStorage, keys: newKeys)
        document.storage.encodedLength = newSize
        return document
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
            // setup to overwrite null terminator
            self.storage.buffer.moveWriterIndex(to: self.storage.encodedLength - 1)
            let size = self.storage.append(key: key, value: value)
            self.storage.buffer.writeInteger(0, endianness: .little, as: UInt8.self) // add back in our null terminator
            self.storage.encodedLength += size
            return
        }

        guard let range = try BSONDocumentIterator.findByteRange(for: key, in: self) else {
            throw BSONError.InternalError(message: "Cannot find \(key) to delete")
        }

        let prefixLength = range.startIndex
        let suffixLength = self.storage.encodedLength - range.endIndex

        guard
            let prefix = self.storage.buffer.getBytes(at: 0, length: prefixLength),
            let suffix = self.storage.buffer.getBytes(at: range.endIndex, length: suffixLength)
        else {
            throw BSONError.InternalError(
                message: "Cannot slice buffer from " +
                    "0 to len \(range.startIndex) and from \(range.endIndex) " +
                    "to len \(suffixLength) : \(self.storage.buffer)"
            )
        }

        var newStorage = BSONDocumentStorage()
        newStorage.buffer.writeBytes(prefix)

        var newSize = self.storage.encodedLength - (range.endIndex - range.startIndex)
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
        self.storage.encodedLength = newSize
        guard self.storage.encodedLength == self.storage.buffer.readableBytes else {
            fatalError("BSONDocument's encoded byte length is \(self.storage.encodedLength), however the " +
                "buffer has \(self.storage.buffer.readableBytes) readable bytes")
        }
    }

    /// Storage management for BSONDocuments.
    /// A wrapper around a ByteBuffer providing various BSONDocument-specific utilities.
    internal struct BSONDocumentStorage {
        internal var buffer: ByteBuffer

        /// Create BSONDocumentStorage from ByteBuffer.
        internal init(_ buffer: ByteBuffer) { self.buffer = buffer }

        /// Create BSONDocumentStorage with a 0 capacity buffer.
        internal init() { self.buffer = BSON_ALLOCATOR.buffer(capacity: 0) }

        internal var encodedLength: Int {
            get {
                guard let encodedLength = self.buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
                    fatalError("Cannot read encoded Length of BSON from buffer")
                }
                return Int(encodedLength)
            }
            set {
                guard newValue <= Int32.max else {
                    fatalError("Cannot cast \(newValue) down to Int32")
                }
                self.buffer.setInteger(Int32(newValue), at: 0, endianness: .little, as: Int32.self)
            }
        }

        /// Appends element to underlying BSON bytes, returns the size of the element appended: type + key + value
        @discardableResult internal mutating func append(key: String, value: BSON) -> Int {
            let writer = self.buffer.writerIndex
            self.appendElementHeader(key: key, bsonType: value.bsonValue.bsonType)
            value.bsonValue.write(to: &self.buffer)
            return self.buffer.writerIndex - writer
        }

        /// Append the header (key and BSONType) for a given element.
        @discardableResult internal mutating func appendElementHeader(key: String, bsonType: BSONType) -> Int {
            let writer = self.buffer.writerIndex
            self.buffer.writeInteger(bsonType.rawValue, as: UInt8.self)
            self.buffer.writeCString(key)
            return self.buffer.writerIndex - writer
        }

        /// Build a document at the current position in the storage via the provided closure which appends
        /// the elements of the document and returns how many bytes it wrote in total. This method will append the
        /// required metadata surrounding the document as necessary (length, null byte).
        ///
        /// If this method is used to build a subdocument, the caller is responsible for updating
        /// the length of the containing document based on this method's return value. If this method was invoked
        /// recursively from `buildDocument`, such updating will happen automatically if the returned byte count
        /// is propagated.
        ///
        /// This may be used to build up a fresh document or a subdocument.
        internal mutating func buildDocument(_ appendElementsFunc: (inout Self) throws -> Int) rethrows -> Int {
            var totalBytes = 0

            // write placeholder length of document
            let lengthIndex = self.buffer.writerIndex
            totalBytes += self.buffer.writeInteger(0, endianness: .little, as: Int32.self)

            // write contents
            totalBytes += try appendElementsFunc(&self)

            // write null byte
            totalBytes += self.buffer.writeInteger(0, as: UInt8.self)

            self.buffer.setInteger(Int32(totalBytes), at: lengthIndex, endianness: .little, as: Int32.self)

            return totalBytes
        }

        @discardableResult
        internal func validateAndRetrieveKeys() throws -> Set<String> {
            // Pull apart the underlying binary into [KeyValuePair], should reveal issues
            guard let encodedLength = self.buffer.getInteger(at: 0, endianness: .little, as: Int32.self) else {
                throw BSONError.InvalidArgumentError(message: "Validation Failed: Cannot read encoded length")
            }

            guard encodedLength >= BSON_MIN_SIZE && encodedLength <= BSON_MAX_SIZE else {
                throw BSONError.InvalidArgumentError(
                    message: "Validation Failed: BSON cannot be \(encodedLength) bytes long"
                )
            }

            guard encodedLength == self.buffer.readableBytes else {
                throw BSONError.InvalidArgumentError(
                    message: "BSONDocument's encoded byte length is \(encodedLength), however the" +
                        "buffer has \(self.buffer.readableBytes) readable bytes"
                )
            }

            var keySet = Set<String>()
            let iter = BSONDocumentIterator(over: self.buffer)
            // Implicitly validate with iterator
            do {
                while let (key, value) = try iter.nextThrowing() {
                    let (inserted, _) = keySet.insert(key)
                    guard inserted else {
                        throw BSONError.InvalidArgumentError(
                            message: "Validation Failed: BSON contains multiple values for key \(key)"
                        )
                    }
                    switch value {
                    case let .document(doc):
                        try doc.storage.validateAndRetrieveKeys()
                    case let .array(array):
                        for item in array {
                            if let doc = item.documentValue {
                                try doc.storage.validateAndRetrieveKeys()
                            }
                        }
                    default:
                        continue
                    }
                }
            } catch let error as BSONError.InternalError {
                throw BSONError.InvalidArgumentError(
                    message: "Validation Failed: \(error.message)"
                )
            }

            return keySet
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
    internal static let extJSONTypeWrapperKeys: [String] = []

    /*
     * Initializes a `BSONDocument` from ExtendedJSON.
     * This is not as performant as ExtendedJSONDecoder.decode, so it should only be used for small documents.
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
        guard case let .object(obj) = json.value else {
            return nil
        }
        var doc: [(String, BSON)] = []
        for (key, val) in obj {
            let bsonValue = try BSON(fromExtJSON: JSON(val), keyPath: keyPath + [key])
            doc.append((key, bsonValue))
        }
        self = BSONDocument(keyValuePairs: doc)
    }

    /// Converts this `BSONDocument` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        var obj: [String: JSONValue] = [:]
        for (key, value) in self {
            obj[key] = value.toRelaxedExtendedJSON().value
        }
        return JSON(.object(obj))
    }

    /// Converts this `BSONDocument` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        var obj: [String: JSONValue] = [:]
        for (key, value) in self {
            obj[key] = value.toCanonicalExtendedJSON().value
        }
        return JSON(.object(obj))
    }

    internal static var bsonType: BSONType { .document }

    internal var bson: BSON { .document(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        let reader = buffer.readerIndex
        guard let encodedLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Cannot read document byte length")
        }
        buffer.moveReaderIndex(to: reader)
        guard let bytes = buffer.readSlice(length: Int(encodedLength)) else {
            throw BSONError.InternalError(message: "Cannot read document contents")
        }

        let keys = try BSONDocumentIterator.getKeySet(from: bytes)
        return .document(BSONDocument(fromUnsafeBSON: BSONDocument.BSONDocumentStorage(bytes), keys: keys))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeBytes(self.storage.buffer.readableBytesView)
    }
}

extension BSONDocument: CustomStringConvertible {
    public var description: String { self.toExtendedJSONString() }
}

extension BSONDocument {
    /**
     * Returns whether this `BSONDocument` contains exactly the same key/value pairs as the provided `BSONDocument`,
     * regardless of the order of the keys.
     *
     * Warning: This method is much less efficient than checking for regular equality since the document is internally
     * ordered.
     *
     * - Parameters:
     *   - other: a `BSONDocument` to compare this document with.
     *
     * - Returns: a `Bool` indicating whether the two documents are equal.
     */
    public func equalsIgnoreKeyOrder(_ other: BSONDocument) -> Bool {
        guard self.count == other.count else {
            return false
        }

        for (k, v) in self {
            let otherValue = other[k]
            if case let (.document(docA), .document(docB)?) = (v, otherValue) {
                guard docA.equalsIgnoreKeyOrder(docB) else {
                    return false
                }
                continue
            }
            guard v == otherValue else {
                return false
            }
        }

        return true
    }
}
