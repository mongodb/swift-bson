import NIO

extension ByteBuffer {
    /// Write null terminated string into this ByteBuffer using UTF-8 encoding,
    /// moving the writer index forward by the byte length of string + 1 (for null terminator).
    @discardableResult
    internal mutating func writeCString(_ string: String) -> Int {
        let written = self.writeString(string + "\0")
        return written
    }

    /// Read bytes off this ByteBuffer until encountering null, decoding it as String using the UTF-8 encoding.
    /// moving the reader index forward by the byte length of string + 1 (for null terminator).
    internal mutating func readCString() throws -> String {
        var bytes: [UInt8] = []
        for _ in 0..<BSON_MAX_SIZE {
            guard let b = self.readBytes(length: 1) else {
                throw BSONError.InternalError(message: "Failed to read CString, unable to read byte from \(self)")
            }
            guard b[0] != 0 else {
                guard let string = String(bytes: bytes, encoding: .utf8) else {
                    throw BSONError.InternalError(message: "Failed to decode CString as UTF8: \(bytes)")
                }
                return string
            }
            bytes += b
        }
        throw BSONError.InternalError(message: "Failed to read CString, possibly missing null terminator?")
    }
}
