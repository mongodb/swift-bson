import NIO

extension Bool: BSONValue {
    static var bsonType: BSONType { .bool }

    var bson: BSON { .bool(self) }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(as: UInt8.self) else {
            throw BSONError.InternalError(message: "Could not read Bool")
        }
        guard value == 0 || value == 1 else {
            throw BSONError.InternalError(message: "Bool must be 0 or 1, found:\(value)")
        }
        return .bool(value == 0 ? false : true)
    }

    func write(to buffer: inout ByteBuffer) {
        buffer.writeBytes([self ? 1 : 0])
    }
}
