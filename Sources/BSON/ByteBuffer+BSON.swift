import NIO

extension ByteBuffer {
    /// Write null terminated UTF-8 string to ByteBuffer starting at writerIndex
    @discardableResult
    internal mutating func writeCString(_ string: String) -> Int {
        let written = self.writeString(string + "\0")
        return written
    }

    /// Attempts to read null terminated UTF-8 string from ByteBuffer starting at the readerIndex
    internal mutating func readCString() throws -> String {
        var bytes: [UInt8] = []
        for _ in 0..<BSON_MAX_SIZE {
            guard let b = self.readBytes(length: 1) else {
                throw BSONError.InternalError(message: "Failed to read CString, unable to read byte from \(self)")
            }
            guard b[0] != 0 else {
                guard let string = String(bytes: bytes, encoding: .utf8) else {
                    throw BSONError.InternalError(message: "Failed to decode BSONKey as UTF8: \(bytes)")
                }
                return string
            }
            bytes += b
        }
        throw BSONError.InternalError(message: "Failed to read CString, possibly missing null terminator?")
    }
}
