import Foundation
import NIO

/// :nodoc:
/// Iterator over a `BSONDocument`. This type is not meant to be used directly; please use `Sequence` protocol methods
/// instead.
public class BSONDocumentIterator: IteratorProtocol {
    /// The buffer we are iterating over.
    private var buffer: ByteBuffer
    private var exhausted: Bool

    internal init(over buffer: ByteBuffer) {
        self.buffer = buffer
        self.exhausted = false
        // moves readerIndex to first key's type indicator
        self.buffer.moveReaderIndex(to: 4)
    }

    internal convenience init(over doc: BSONDocument) {
        self.init(over: doc.buffer)
    }

    /// Advances to the next element and returns it, or nil if no next element exists.
    public func next() -> BSONDocument.KeyValuePair? {
        // The only time this would crash is when the document is incorrectly formatted
        do {
            return try self.nextThrowing()
        } catch {
            fatalError("Failed to iterate to next: \(error)")
        }
    }

    /**
     * Advances to the next element and returns it, or nil if no next element exists.
     * - Throws:
     *   - `InternalError` if the underlying buffer contains invalid BSON
     */
    internal func nextThrowing() throws -> BSONDocument.KeyValuePair? {
        guard let type = try self.readNextType() else {
            return nil
        }
        let key = try self.buffer.readCString()
        guard let bson = try BSON.allBSONTypes[type]?.read(from: &self.buffer) else {
            throw BSONIterationError(message: "Encountered invalid BSON type: \(type)")
        }
        return (key: key, value: bson)
    }

    /// Get the next key in the iterator, if there is one.
    /// This method should only be used for iterating through the keys. It advances to the beginning of the next
    /// element, meaning the element associated with the last returned key cannot be accessed via this iterator.
    private func nextKey() throws -> String? {
        guard let type = try self.readNextType() else {
            return nil
        }
        let key = try self.buffer.readCString()
        try self.skipNextValue(type: type)
        return key
    }

    /// Assuming the buffer is currently positioned at the start of an element, returns the BSON type for the element.
    /// Returns nil if the end of the document has been reached.
    /// Throws an error if the byte does not correspond to a BSON type.
    internal func readNextType() throws -> BSONType? {
        guard !self.exhausted else {
            return nil
        }

        guard let nextByte = self.buffer.readInteger(endianness: .little, as: UInt8.self) else {
            throw BSONIterationError(
                buffer: self.buffer,
                message: "There are no readable bytes remaining, but a null terminator was not encountered"
            )
        }

        guard nextByte != 0 else {
            // if we are out of readable bytes, this is the null terminator
            guard self.buffer.readableBytes == 0 else {
                throw BSONIterationError(
                    buffer: self.buffer,
                    message: "Encountered invalid type indicator"
                )
            }
            self.exhausted = true
            return nil
        }

        guard let bsonType = BSONType(rawValue: nextByte) else {
            throw BSONIterationError(
                buffer: self.buffer,
                message: "Encountered invalid BSON type indicator \(nextByte)"
            )
        }

        return bsonType
    }

    /// Finds an element with the specified key in the document. Returns nil if the key is not found.
    internal static func find(key: String, in document: BSONDocument) throws -> BSONDocument.KeyValuePair? {
        let iter = document.makeIterator()
        while let type = try iter.readNextType() {
            let foundKey = try iter.buffer.readCString()
            if foundKey == key {
                // the map contains a value for every valid BSON type.
                // swiftlint:disable:next force_unwrapping
                let bson = try BSON.allBSONTypes[type]!.read(from: &iter.buffer)
                return (key: key, value: bson)
            }

            try iter.skipNextValue(type: type)
        }
        return nil
    }

    /// Given the type of the encoded value starting at self.buffer.readerIndex, advances the reader index to the index
    /// after the end of the element.
    internal func skipNextValue(type: BSONType) throws {
        switch type {
        case .invalid:
            fatalError("Unexpectedly encountered invalid BSON type")

        case .undefined, .null, .minKey, .maxKey:
            // no data stored, nothing to skip.
            return

        case .bool:
            self.buffer.moveReaderIndex(forwardBy: 1)

        case .double, .int64, .timestamp, .datetime:
            self.buffer.moveReaderIndex(forwardBy: 8)

        case .objectID:
            self.buffer.moveReaderIndex(forwardBy: 12)

        case .int32:
            self.buffer.moveReaderIndex(forwardBy: 4)

        case .string, .code, .symbol:
            guard let strLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                throw BSONError.InternalError(message: "Failed to read encoded string length")
            }
            self.buffer.moveReaderIndex(forwardBy: Int(strLength))

        case .regex:
            _ = try self.buffer.readCString()
            _ = try self.buffer.readCString()

        case .binary:
            guard let dataLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                throw BSONError.InternalError(message: "Failed to read encoded binary data length")
            }
            self.buffer.moveReaderIndex(forwardBy: Int(dataLength) + 1) // +1 for the binary subtype.

        case .document, .array, .codeWithScope:
            guard let embeddedDocLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                throw BSONError.InternalError(message: "Failed to read encoded document length")
            }
            // -4 because the encoded length includes the bytes necessary to store the length itself.
            self.buffer.moveReaderIndex(forwardBy: Int(embeddedDocLength) - 4)

        case .dbPointer:
            // initial string
            guard let strLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                throw BSONError.InternalError(message: "Failed to read encoded string length")
            }
            self.buffer.moveReaderIndex(forwardBy: Int(strLength))
            // 12 bytes of data
            self.buffer.moveReaderIndex(forwardBy: 12)

        case .decimal128:
            self.buffer.moveReaderIndex(forwardBy: 16)
        }
    }

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element.
    internal static func findByteRange(for searchKey: String, in document: BSONDocument) throws -> Range<Int>? {
        let iter = document.makeIterator()

        while true {
            let startIndex = iter.buffer.readerIndex
            guard let type = try iter.readNextType() else {
                return nil
            }
            let foundKey = try iter.buffer.readCString()
            try iter.skipNextValue(type: type)

            if foundKey == searchKey {
                let endIndex = iter.buffer.readerIndex
                return startIndex..<endIndex
            }
        }
    }

    /// Retrieves an ordered list of the keys in the provided document buffer.
    internal static func getKeys(from buffer: ByteBuffer) throws -> [String] {
        let iter = BSONDocumentIterator(over: buffer)
        var keys = [String]()
        while let key = try iter.nextKey() {
            keys.append(key)
        }
        return keys
    }

    /// Retrieves an unordered list of the keys in the provided document buffer.
    internal static func getKeySet(from buffer: ByteBuffer) throws -> Set<String> {
        let iter = BSONDocumentIterator(over: buffer)
        var keySet: Set<String> = []
        while let key = try iter.nextKey() {
            keySet.insert(key)
        }
        return keySet
    }

    // uses an iterator to copy (key, value) pairs of the provided document from range [startIndex, endIndex) into a new
    // document. starts at the startIndex-th pair and ends at the end of the document or the (endIndex-1)th index,
    // whichever comes first.
    internal static func subsequence(
        of doc: BSONDocument,
        startIndex: Int = 0,
        endIndex: Int = Int.max
    ) -> BSONDocument {
        // TODO: SWIFT-911 Improve performance
        guard endIndex >= startIndex else {
            fatalError("endIndex must be >= startIndex")
        }

        let iter = BSONDocumentIterator(over: doc)

        do {
            for _ in 0..<startIndex {
                guard let type = try iter.readNextType() else {
                    // we ran out of values
                    break
                }
                _ = try iter.buffer.readCString()
                try iter.skipNextValue(type: type)
            }

            var newDoc = BSONDocument()

            for _ in startIndex..<endIndex {
                guard let next = try iter.nextThrowing() else {
                    // we ran out of values
                    break
                }
                newDoc[next.key] = next.value
            }

            return newDoc
        } catch {
            fatalError("Failed to retrieve document subsequence: \(error)")
        }
    }
}

extension BSONDocument {
    // this is an alternative to the built-in `BSONDocument.filter` that returns an `[KeyValuePair]`. this variant is
    // called by default, but the other is still accessible by explicitly stating return type:
    // `let newDocPairs: [BSONDocument.KeyValuePair] = newDoc.filter { ... }`
    /**
     * Returns a new document containing the elements of the document that satisfy the given predicate.
     *
     * - Parameters:
     *   - isIncluded: A closure that takes a key-value pair as its argument and returns a `Bool` indicating whether
     *                 the pair should be included in the returned document.
     *
     * - Returns: A document containing the key-value pairs that `isIncluded` allows.
     *
     * - Throws: An error if `isIncluded` throws an error.
     */
    public func filter(_ isIncluded: (KeyValuePair) throws -> Bool) rethrows -> BSONDocument {
        var elements: [BSONDocument.KeyValuePair] = []
        for pair in self where try isIncluded(pair) {
            elements.append(pair)
        }
        return BSONDocument(keyValuePairs: elements)
    }
}
