import NIO

extension Int32: BSONValue {
    internal init(fromExtJSON json: JSON) throws {
        switch json {
        case let .object(obj):
            guard let str = obj["$numberInt"]?.stringValue else {
                throw BSONError.InternalError(message: "Not a valid Int32")
            }
            guard let int = Int32(str) else {
                throw BSONError.InternalError(message: "Not a valid Int32")
            }
            self = int
        default:
            throw BSONError.InternalError(message: "Not a valid Int32")
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
