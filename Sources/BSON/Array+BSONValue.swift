import NIO

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue where Element == BSON {
    internal static var bsonType: BSONType { .array }

    internal var bson: BSON { .array(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let doc = try BSONDocument.read(from: &buffer).documentValue else {
            throw BSONError.InternalError(message: "BSON Array cannot be read, failed to get documentValue")
        }
        return .array(doc.values)
    }

    internal func write(to buffer: inout ByteBuffer) {
        var array = BSONDocument()
        for (index, value) in self.enumerated() {
            array[String(index)] = value
        }
        array.write(to: &buffer)
    }
}
