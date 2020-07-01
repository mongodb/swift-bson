import Foundation
import NIO

public struct BSONDocumentIterator: IteratorProtocol {
    /// The buffer we are iterating over.
    private var buffer: ByteBuffer
    private var exhausted: Bool

    internal init(over buffer: ByteBuffer) {
        self.buffer = buffer
        self.exhausted = false
        // moves readerIndex to first key's type indicator
        self.buffer.moveReaderIndex(to: 4)
    }

    internal init(over doc: BSONDocument) {
        self = BSONDocumentIterator(over: doc.buffer)
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
            guard self.exhausted else {
                throw BSONIterationError(
                    buffer: self.buffer,
                    message: "There are no readable bytes remaining but a null terminator was not encountered"
                )
            }
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
            guard self.buffer.readableBytes == 0 else {
                throw BSONIterationError(
                    buffer: self.buffer,
                    message: "Bytes remain after document iteration exhausted"
                )
            }
            self.exhausted = true
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

        var iter = BSONDocumentIterator(over: doc)

        var excludedKeys: [String] = []

        for _ in 0..<startIndex {
            guard let next = iter.next() else {
                // we ran out of values
                break
            }
            excludedKeys.append(next.key)
        }

        // skip the values between startIndex and endIndex. this has better performance than calling next, because
        // it doesn't pull the unneeded key/values out of the iterator
        for _ in startIndex..<endIndex {
            guard (try? iter.nextThrowing()) != nil else {
                // we ran out of values
                break
            }
        }

        while let next = iter.next() {
            excludedKeys.append(next.key)
        }

        guard !excludedKeys.isEmpty else {
            return doc
        }

        let newDoc = doc.filter { key, _ in !excludedKeys.contains(key) }
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
        return BSONDocument(keyValuePairs: elements)
    }
}
