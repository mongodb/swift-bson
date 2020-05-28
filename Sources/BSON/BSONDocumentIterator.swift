import Foundation
import NIO

extension BSONDocument: Sequence {
    // Since a `Document` is a recursive structure, we want to enforce the use of it as a subsequence of itself,
    // instead of something like `Slice<Document>`.
    /// The type that is returned from methods such as `dropFirst()` and `split()`.
    public typealias SubSequence = BSONDocument

    /// Returns a `Bool` indicating whether the document is empty.
    public var isEmpty: Bool { self.size == 5 }

    /// Returns a `DocumentIterator` over the values in this `Document`.
    public func makeIterator() -> BSONDocumentIterator {
        BSONDocumentIterator(over: self.buffer)
    }
}

public struct BSONDocumentIterator: IteratorProtocol {
    /// The buffer we are iterating over.
    private var buffer: ByteBuffer
    private let size: Int32

    internal init(over buffer: ByteBuffer) {
        self.buffer = buffer
        // moves readerIndex to first key's type indicator
        self.size = self.buffer.readInteger(endianness: .little, as: Int32.self) ?? 5
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

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element (includes from beginning of key to end of value).
    internal func findByteRange(for keyString: String) -> (startIndex: Int, length: Int) {
        fatalError("Unimplemented")
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
        fatalError("Unimplemented")
    }
}
