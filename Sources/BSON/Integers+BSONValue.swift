import NIO

extension Int32: BSONValue {
    /// Initializes an `Int32` given well-formatted canonical or relaxed extended JSON representing an `Int32`
    /// Returns `nil` if the provided value is not an Int32.
    /// Throws if the JSON is a partial match or is malformed.
    internal init?(fromExtJSON json: JSON) throws {
        switch json {
        case let .number(n):
            // relaxed extended JSON
            guard let int = Int32(exactly: n) else {
                return nil
            }
            self = int
        case let .object(obj):
            // canonical extended JSON
            guard let value = obj["$numberInt"]?.stringValue else {
                return nil
            }
            guard obj.count == 1 else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: "Not a valid Int32"
                    )
                )
            }
            guard let int = Int32(value) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: "Not a valid Int32"
                    )
                )
            }
            self = int
        default:
            return nil
        }
    }

    internal static var bsonType: BSONType { .int32 }

    internal var bson: BSON { .int32(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 32-bit integer")
        }
        return .int32(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int32.self)
    }
}

extension Int64: BSONValue {
    internal static var bsonType: BSONType { .int64 }

    internal var bson: BSON { .int64(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 64-bit integer")
        }
        return .int64(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int64.self)
    }
}
