import NIO

extension Int32: BSONValue {
    static var bsonType: BSONType { .int32 }

    var bson: BSON { .int32(self) }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 32-bit integer")
        }
        return .int32(value)
    }

    func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int32.self)
    }
}

extension Int64: BSONValue {
    static var bsonType: BSONType { .int64 }

    var bson: BSON { .int64(self) }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 64-bit integer")
        }
        return .int64(value)
    }

    func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int64.self)
    }
}
