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
    public mutating func next() -> BSONDocument.KeyValuePair? {
        // The only time this would crash is when the document is incorrectly formatted
        // swiftlint:disable force_try
        try! self.nextThrowing()
    }

    /**
     * Advances to the next element and returns it, or nil if no next element exists.
     * - Throws:
     *   - `InternalError` if the underlying buffer contains invalid BSON
     */
    internal mutating func nextThrowing() throws -> BSONDocument.KeyValuePair? {
        guard self.buffer.readableBytes != 0 else {
            // Iteration has been exhausted
            return nil
        }

        guard let typeByte = self.buffer.readInteger(as: UInt8.self) else {
            throw BSONIterationError(
                buffer: self.buffer,
                message: "Cannot read type indicator from bson"
            )
        }

        guard typeByte != 0 else {
            // Iteration exhausted after we've read the null terminator (special case)
            return nil
        }

        guard let type = BSONType(rawValue: typeByte), type != .invalid else {
            throw BSONIterationError(
                buffer: self.buffer,
                typeByte: typeByte,
                message: "Invalid type indicator"
            )
        }

        let key = try self.buffer.readCString()
        guard let bson = try BSON.allBSONTypes[type]?.read(from: &buffer) else {
            throw BSONIterationError(
                buffer: self.buffer,
                key: key,
                type: type,
                typeByte: typeByte,
                message: "Cannot decode type"
            )
        }
        return (key: key, value: bson)
    }

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element.
    internal mutating func findByteRange(for searchKey: String) -> Range<Int>? {
        while true {
            let startIndex = self.buffer.readerIndex
            guard let (key, _) = self.next() else {
                // Iteration ended without finding a match
                return nil
            }
            let endIndex = self.buffer.readerIndex

            if key == searchKey {
                return startIndex..<endIndex
            }
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
