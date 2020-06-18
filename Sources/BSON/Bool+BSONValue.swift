import NIO

extension Bool: BSONValue {
    internal static var bsonType: BSONType { .bool }

    internal var bson: BSON { .bool(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(as: UInt8.self) else {
            throw BSONError.InternalError(message: "Could not read Bool")
        }
        guard value == 0 || value == 1 else {
            throw BSONError.InternalError(message: "Bool must be 0 or 1, found:\(value)")
        }
        return .bool(value == 0 ? false : true)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeBytes([self ? 1 : 0])
    }
}
