import NIO

public struct BSONTimestamp: BSONValue, Equatable, Hashable {
    internal static var bsonType: BSONType { .timestamp }
    internal var bson: BSON { .timestamp(self) }

    /// A timestamp representing seconds since the Unix epoch.
    public let timestamp: UInt32
    /// An incrementing ordinal for operations within a given second.
    public let increment: UInt32

    /// Initializes a new  `BSONTimestamp` with the provided `timestamp` and `increment` values.
    public init(timestamp: UInt32, inc: UInt32) {
        self.timestamp = timestamp
        self.increment = inc
    }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let increment = buffer.readInteger(endianness: .little, as: UInt32.self) else {
            throw BSONError.InternalError(message: "Cannot read increment from BSON timestamp")
        }
        guard let timestamp = buffer.readInteger(endianness: .little, as: UInt32.self) else {
            throw BSONError.InternalError(message: "Cannot read timestamp from BSON timestamp")
        }
        return .timestamp(BSONTimestamp(timestamp: timestamp, inc: increment))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.increment, endianness: .little, as: UInt32.self)
        buffer.writeInteger(self.timestamp, endianness: .little, as: UInt32.self)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}
