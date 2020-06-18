import NIO

/// A struct to represent the BSON ObjectID type.
public struct BSONObjectID: Equatable, Hashable, CustomStringConvertible {
    /// This `BSONObjectID`'s data represented as a `String`.
    public var hex: String { fatalError("ah") }

    public var description: String {
        self.hex
    }

    internal let oid: [UInt8]

    /// Initializes a new `BSONObjectID`.
    public init() {
        fatalError("ah")
    }

    /// Initializes a new `BSONObjectID`.
    internal init(_ bytes: [UInt8]) {
        self.oid = bytes
    }

    /// Initializes an `BSONObjectID` from the provided hex `String`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if string passed is not a valid BSONObjectID
    /// - SeeAlso: https://github.com/mongodb/specifications/blob/master/source/objectid.rst
    public init(_ hex: String) throws {
        fatalError("ah")
    }
}

extension BSONObjectID: BSONValue {
    internal static var bsonType: BSONType { .objectID }

    internal var bson: BSON { .objectID(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let bytes = buffer.readBytes(length: 12) else {
            throw BSONError.InternalError(message: "Cannot read 12 bytes for BSONObjectID")
        }
        return .objectID(BSONObjectID(bytes))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeBytes(self.oid)
    }
}
