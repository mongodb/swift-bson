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
        let string = try self.getCString(at: self.readerIndex)
        self.moveReaderIndex(forwardBy: string.utf8.count + 1)
        return string
    }

    /// Attempts to read null terminated UTF-8 string from ByteBuffer starting at the readerIndex
    internal func getCString(at offset: Int) throws -> String {
        var string: [UInt8] = []
        for i in 0..<Int(BSON_MAX_SIZE) {
            if let b = self.getBytes(at: offset + i, length: 1) {
                if b[0] == 0 {
                    guard let s = String(bytes: string, encoding: .utf8) else {
                        throw BSONError.InternalError(message: "Unable to decode utf8 string from \(string)")
                    }
                    return s
                }
                string += b
            } else {
                throw BSONError.InternalError(message: "Failed to read CString, unable to read byte from \(self)")
            }
        }
        throw BSONError.InternalError(message: "Failed to read CString, possibly missing null terminator?")
    }
}
