import NIO

extension Double: BSONValue {
    internal static var bsonType: BSONType { .double }

    internal var bson: BSON { .double(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let data = buffer.readBytes(length: 8) else {
            throw BSONError.InternalError(message: "Cannot read 8 bytes")
        }
        var value = Double()
        let bytesCopied = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
        guard bytesCopied == MemoryLayout.size(ofValue: value) else {
            throw BSONError.InternalError(message: "Cannot initialize Double from bytes \(data)")
        }
        return .double(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        let data = withUnsafeBytes(of: self) { [UInt8]($0) }
        buffer.writeBytes(data)
    }
}
