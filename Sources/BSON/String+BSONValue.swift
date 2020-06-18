import NIO

extension String: BSONValue {
    internal static var bsonType: BSONType { .string }

    internal var bson: BSON { .string(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let length = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Cannot read string length")
        }
        guard length > 0 else {
            throw BSONError.InternalError(message: "String length is always >= 1 for null terminator")
        }
        guard let bytes = buffer.readBytes(length: Int(length)) else {
            throw BSONError.InternalError(message: "Cannot read string")
        }
        guard let nullTerm = bytes.last, nullTerm == 0 else {
            throw BSONError.InternalError(message: "String is not null terminated")
        }
        guard let string = String(bytes: bytes.dropLast(), encoding: .utf8) else {
            throw BSONError.InternalError(message: "Invalid UTF8")
        }
        return .string(string)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(Int32(self.utf8.count + 1), endianness: .little, as: Int32.self)
        buffer.writeBytes(self.utf8)
        buffer.writeInteger(0, as: UInt8.self)
    }
}
