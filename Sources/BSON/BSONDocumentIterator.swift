import Foundation
import NIO

extension BSONDocument: Sequence {
    // Since a `Document` is a recursive structure, we want to enforce the use of it as a subsequence of itself,
    // instead of something like `Slice<Document>`.
    /// The type that is returned from methods such as `dropFirst()` and `split()`.
    public typealias SubSequence = BSONDocument

    /// Returns a `Bool` indicating whether the document is empty.
    public var isEmpty: Bool { self.keySet.isEmpty }

    /// Returns a `DocumentIterator` over the values in this `Document`.
    public func makeIterator() -> BSONDocumentIterator {
        BSONDocumentIterator(over: self.buffer)
    }
}

public struct BSONDocumentIterator: IteratorProtocol {
    /// The buffer we are iterating over.
    private var buffer: ByteBuffer

    internal init(over buffer: ByteBuffer) {
        self.buffer = buffer
        // moves readerIndex to first key's type indicator
        self.buffer.moveReaderIndex(to: 4)
    }

    /// Advances to the next element and returns it, or nil if no next element exists.
    public mutating func next() -> (String, BSON)? {
        let typeByte = self.buffer.readInteger(as: UInt8.self) ?? BSONType.invalid.rawValue
        guard let type = BSONType(rawValue: typeByte), type != .invalid else {
            return nil
        }
        guard let key = try? self.buffer.readCString() else {
            return nil
        }
        guard let bson = try? BSON.allBSONTypes[type]?.read(from: &buffer) else {
            return nil
        }
        return (key, bson)
    }

    /**
     * Find the starting index and length of a BSON Element
     * - Parameter for: the key used to locate the element
     */
    internal func findByteRange(for key: String) -> (startIndex: Int, length: Int)? {
        let key = [UInt8](key.utf8 + [0])

        let typeIndicatorSize = 1

        var start = 4
        while self.buffer.readableBytes > key.count {
            guard let view = self.buffer.getBytes(at: start + 1, length: key.count) else {
                // Cannot read bytes of length key
                return nil
            }

            if key == view {
                // found element
                guard let size = BSONDocumentIterator.size(at: start, in: self.buffer) else {
                    return nil
                }
                return (start, key.count + size + typeIndicatorSize)
            }

            start += 1
        }
        return nil
    }

    private static let bsonSizeMap: [BSONType: Int] = [
        .bool: 1,
        .datetime: 8,
        .decimal128: 16,
        .double: 8,
        .int32: 4,
        .int64: 8,
        .maxKey: 0,
        .minKey: 0,
        .null: 0,
        .objectId: 12,
        .timestamp: 8,
        .undefined: 0
    ]

    /**
     * Get the size of a BSON Value
     * Examples:
     * - A BSON Int64 will return 8
     * - A BSON Array [Int64(1), Int64(2)] will return 27
     *
     * - Parameter at: the index into the buffer where the type indicator for the element is
     * - Parameter in: the buffer to read type and size information from
     */
    internal static func size(at position: Int, in buffer: ByteBuffer) -> Int? {
        let type = buffer.getBSONType(at: position)

        guard type != .invalid else {
            return nil
        }

        if let size = bsonSizeMap[type] {
            return size
        }

        do {
            let key = try buffer.getBSONKey(at: position + 1)
            // types with sizes encoded into the bson
            let typesWithSizes = [BSONType]([.string, .binary, .code, .symbol])
            if typesWithSizes.contains(type) {
                guard let size = buffer.getInteger(
                    at: position + key.count + 1, endianness: .little, as: Int32.self
                ) else {
                    return nil
                }
                // add 4 for the size int32
                return Int(size) + 4
            }

            let typesWithSizesUninclusize = [BSONType]([.codeWithScope, .document, .array])
            if typesWithSizesUninclusize.contains(type) {
                guard let size = buffer.getInteger(
                    at: position + key.count + 1, endianness: .little, as: Int32.self
                ) else {
                    return nil
                }
                // add 4 for the size int32
                return Int(size)
            }

            // types that need their size calculated
            if type == .regex {
                do {
                    let key = try buffer.getCString(at: position + 1).utf8
                    let regexLength = try buffer.getCString(at: position + 1 + key.count + 1).utf8.count + 1
                    let flagsLength = try buffer.getCString(
                        at: position + 1 + key.count + 1 + regexLength
                    ).utf8.count + 1
                    let valueSize = regexLength + flagsLength
                    return valueSize
                } catch {
                    return nil
                }
            }

            return nil
        } catch {
            return nil
        }
    }
}

extension BSONDocument {
    // this is an alternative to the built-in `Document.filter` that returns an `[KeyValuePair]`. this variant is
    // called by default, but the other is still accessible by explicitly stating return type:
    // `let newDocPairs: [Document.KeyValuePair] = newDoc.filter { ... }`
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
        var pairs: [KeyValuePair] = []
        for keyValuePair in self {
            if try isIncluded(keyValuePair) {
                pairs.append(keyValuePair)
            }
        }
        return BSONDocument(keyValuePairs: pairs)
    }
}
