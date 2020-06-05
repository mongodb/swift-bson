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
        guard self.buffer.readableBytes != 0 else {
            // Iteration has been exhuasted
            return nil
        }

        guard let typeByte = self.buffer.readInteger(as: UInt8.self) else {
            fatalError("BSONDocumentIterator Failed: Cannot read from \(self.buffer)")
        }

        guard let type = BSONType(rawValue: typeByte), type != .invalid else {
            if typeByte == 0 {
                // Iteration exhuasted after we've read the null terminator (special case)
                return nil
            }
            fatalError("BSONDocumentIterator Failed: Invalid type, \(typeByte)")
        }

        do {
            let key = try self.buffer.readCString()
            guard let bson = try BSON.allBSONTypes[type]?.read(from: &buffer) else {
                throw BSONError.InternalError(message: "Cannot read unknown type: \(type)")
            }
            return (key, bson)
        } catch {
            fatalError("BSONDocumentIterator.next() failed: \(error)")
        }
    }

    /// Finds the key in the underlying buffer, and returns the [startIndex, endIndex) containing the corresponding
    /// element.
    internal func findByteRange(for key: String) -> (startIndex: Int, endIndex: Int) {
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
