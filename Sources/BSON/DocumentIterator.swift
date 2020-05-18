import Foundation
import NIO

extension Document: Sequence {
    // Since a `Document` is a recursive structure, we want to enforce the use of it as a subsequence of itself,
    // instead of something like `Slice<Document>`.
    /// The type that is returned from methods such as `dropFirst()` and `split()`.
    public typealias SubSequence = Document

    /// Returns a `Bool` indicating whether the document is empty.
    public var isEmpty: Bool { fatalError("Unimplemented") }

    /// Returns a `DocumentIterator` over the values in this `Document`.
    public func makeIterator() -> DocumentIterator {
        DocumentIterator(over: self.buffer)
    }
}

public struct DocumentIterator: IteratorProtocol {
    /// The buffer we are iterating over.
    private var buffer: ByteBuffer

    internal init(over buffer: ByteBuffer) {
        self.buffer = buffer
        _ = self.buffer.readInteger(as: Int32.self) // put the readerIndex at the first key
    }

    /// Advances to the next element and returns it, or nil if no next element exists.
    public mutating func next() -> (String, BSON)? {
        let typeByte = UInt32(self.buffer.readInteger(as: UInt8.self) ?? BSONType.invalid.toByte)
        guard let type = BSONType(rawValue: typeByte), type != .invalid else {
            return nil
        }
        guard let key = try? self.buffer.readCString() else {
            return nil
        }
        guard let bson = try? DocumentIterator.bsonTypeMap[type]?.read(from: &buffer) else {
            return nil
        }
        return (key, bson)
    }

    private static let bsonTypeMap: [BSONType: BSONValue.Type] = [
        .int32: Int32.self,
        .int64: Int64.self
    ]

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element.
    internal func findByteRange(for key: String) -> (startIndex: Int, endIndex: Int) {
        fatalError("Unimplemented")
    }
}

extension Document {
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
    public func filter(_ isIncluded: (KeyValuePair) throws -> Bool) rethrows -> Document {
        fatalError("Unimplemented")
    }
}
