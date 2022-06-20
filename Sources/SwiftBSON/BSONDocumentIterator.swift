import Foundation
import NIOCore

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
    /// Returns nil if invalid BSON is encountered.
    public func next() -> BSONDocument.KeyValuePair? {
        // soft fail on read error by returning nil.
        // this should only be possible if invalid BSON bytes were provided via
        // BSONDocument.init(fromBSONWithoutValidatingElements:)
        try? self.nextThrowing()
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
    /// Returns nil if invalid BSON is encountered.
    private func nextKey() -> String? {
        guard let type = try? self.readNextType(), let key = try? self.buffer.readCString() else {
            return nil
        }
        guard self.skipNextValue(type: type) else {
            return nil
        }
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

    /// Search for the value associated with the given key, returning its type if found and nil otherwise.
    /// This moves the iterator right up to the first byte of the value.
    /// Returns nil if invalid BSON is encountered.
    internal func findValue(forKey key: String) -> BSONType? {
        guard !self.exhausted else {
            return nil
        }

        let keyUTF8 = key.utf8

        while true {
            var bsonType = BSONType.invalid
            let matchResult = self.buffer.readWithUnsafeReadableBytes { buffer -> (Int, Bool?) in
                var matched = true

                var keyIter = keyUTF8.makeIterator()
                for (i, byte) in buffer.enumerated() {
                    // first byte is type of element
                    guard i != 0 else {
                        guard let type = BSONType(rawValue: byte), type != .invalid else {
                            return (1, nil)
                        }
                        bsonType = type
                        continue
                    }

                    guard byte != 0 else {
                        // hit the null terminator
                        return (i + 1, matched && keyIter.next() == nil)
                    }

                    // if matched the key so far, check the next character
                    if matched {
                        guard let keyByte = keyIter.next() else {
                            matched = false
                            continue
                        }
                        matched = byte == keyByte
                    }
                }

                // unterminated C string, so we read the whole buffer
                return (buffer.count, nil)
            }

            guard let matched = matchResult else {
                // encountered invalid BSON, just return nil
                return nil
            }

            guard matched else {
                guard self.skipNextValue(type: bsonType) else {
                    return nil
                }
                continue
            }

            return bsonType
        }
    }

    /// Finds an element with the specified key in the document. Returns nil if the key is not found.
    /// Returns nil if invalid BSON is encountered when trying to find the key or read the value.
    internal static func find(key: String, in document: BSONDocument) -> BSONDocument.KeyValuePair? {
        let iter = document.makeIterator()

        guard let bsonType = iter.findValue(forKey: key) else {
            return nil
        }
        // the map contains a value for every valid BSON type.
        // swiftlint:disable:next force_unwrapping
        guard let bson = try? BSON.allBSONTypes[bsonType]!.read(from: &iter.buffer) else {
            return nil
        }
        return (key: key, value: bson)
    }

    /// Move the reader index for the underlying buffer forward by the provided amount if possible.
    /// Returns true if the index was moved successfully and false otherwise.
    ///
    /// This will only fail if the underlying buffer contains invalid BSON.
    private func moveReaderIndexSafely(forwardBy amount: Int) -> Bool {
        guard amount > 0 && self.buffer.readerIndex + amount <= self.buffer.writerIndex else {
            return false
        }
        self.buffer.moveReaderIndex(forwardBy: amount)
        return true
    }

    /// Given the type of the encoded value starting at self.buffer.readerIndex, advances the reader index to the index
    /// after the end of the element.
    ///
    /// Returns false if invalid BSON is encountered while trying to skip, returns true otherwise.
    internal func skipNextValue(type: BSONType) -> Bool {
        switch type {
        case .invalid:
            return false

        case .undefined, .null, .minKey, .maxKey:
            // no data stored, nothing to skip.
            break

        case .bool:
            return self.moveReaderIndexSafely(forwardBy: 1)

        case .double, .int64, .timestamp, .datetime:
            return self.moveReaderIndexSafely(forwardBy: 8)

        case .objectID:
            return self.moveReaderIndexSafely(forwardBy: 12)

        case .int32:
            return self.moveReaderIndexSafely(forwardBy: 4)

        case .string, .code, .symbol:
            guard let strLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                return false
            }
            return self.moveReaderIndexSafely(forwardBy: Int(strLength))

        case .regex:
            do {
                _ = try self.buffer.readCString()
                _ = try self.buffer.readCString()
            } catch {
                return false
            }

        case .binary:
            guard let dataLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                return false
            }
            return self.moveReaderIndexSafely(forwardBy: Int(dataLength) + 1) // +1 for the binary subtype.

        case .document, .array, .codeWithScope:
            guard let embeddedDocLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                return false
            }
            // -4 because the encoded length includes the bytes necessary to store the length itself.
            return self.moveReaderIndexSafely(forwardBy: Int(embeddedDocLength) - 4)

        case .dbPointer:
            // initial string
            guard let strLength = buffer.readInteger(endianness: .little, as: Int32.self) else {
                return false
            }
            return self.moveReaderIndexSafely(forwardBy: Int(strLength) + 12)

        case .decimal128:
            return self.moveReaderIndexSafely(forwardBy: 16)
        }

        return true
    }

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element.
    /// Returns nil if invalid BSON is encountered.
    internal static func findByteRange(for searchKey: String, in document: BSONDocument) -> Range<Int>? {
        let iter = document.makeIterator()

        guard let type = iter.findValue(forKey: searchKey) else {
            return nil
        }

        // move back 1 for type byte, 1 for each byte in key, and 1 for null byte
        let startIndex = iter.buffer.readerIndex - 1 - (searchKey.utf8.count + 1)
        guard iter.skipNextValue(type: type) else {
            return nil
        }
        let endIndex = iter.buffer.readerIndex
        return startIndex..<endIndex
    }

    /// Retrieves an ordered list of the keys in the provided document buffer.
    /// If invalid BSON is encountered while retrieving the keys, any valid keys seen up to that point are returned.
    internal static func getKeys(from buffer: ByteBuffer) -> [String] {
        let iter = BSONDocumentIterator(over: buffer)
        var keys = [String]()
        while let key = iter.nextKey() {
            keys.append(key)
        }
        return keys
    }

    // uses an iterator to copy (key, value) pairs of the provided document from range [startIndex, endIndex) into a new
    // document. starts at the startIndex-th pair and ends at the end of the document or the (endIndex-1)th index,
    // whichever comes first.
    // If invalid BSON is encountered before getting to the ith element, a new, empty document will be returned.
    // If invalid BSON is encountered while iterating over elements included in the subsequence, a document containing
    // the elements in the subsequence that came before the invalid BSON will be returned.
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
                guard iter.skipNextValue(type: type) else {
                    break
                }
            }
        } catch {
            // if encountered invalid BSON before reaching the desired portion of the document, just
            // return an empty document
            return BSONDocument()
        }

        var newDoc = BSONDocument()
        for _ in startIndex..<endIndex {
            guard let next = iter.next() else {
                // we ran out of values
                break
            }
            // We can't throw from this method because it's called from the BSONDocument.subscript variant that takes
            // in a range of indexes. We shouldn't encounter errors here, as they only result from a key being an
            // invalid C string or a document being too large. Since we construct keys by reading from an existing doc,
            // there won't be invalid ones, and the resulting document will be no larger than the original as we're
            // taking a subsequence.
            do {
                try newDoc.append(key: next.key, value: next.value)
            } catch {
                fatalError("Error retrieving document subsequence: \(error)")
            }
        }

        return newDoc
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
        // We can't start throwing from here for backward-compat reasons, but also in practice this initializer only
        // throws if the document is too large or any of the keys are invalid C strings. Since we are constructing the
        // document from an existing, valid document, we should not hit either of those errors since all the keys have
        // already been validated and the new document will be no larger than the original document.
        do {
            return try BSONDocument(keyValuePairs: elements)
        } catch {
            fatalError("\(error)")
        }
    }
}
