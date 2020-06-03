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
        var string: [UInt8] = []
        for _ in 0..<BSON_MAX_SIZE {
            if let b = self.readBytes(length: 1) {
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

    /// Get a BSONType byte from self returns .invalid for unknown types.
    internal func getBSONType(at position: Int) -> BSONType {
        guard let bsonType = self.getInteger(at: position).flatMap({ BSONType(rawValue: $0) }) else {
            return .invalid
        }
        return bsonType
    }
}
