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

    /// Attempts to read null terminated UTF-8 string from ByteBuffer starting at the offset
    internal func getCString(at offset: Int) throws -> String {
        let key = try getBSONKey(at: offset).dropLast()
        guard let string = String(bytes: key, encoding: .utf8) else {
            throw BSONError.InternalError(message: "Failed to decode BSONKey as UTF8: \(key)")
        }
        return string
    }

    /// Returns the C String key including the null byte, for ease of comparison and byte counting
    internal func getBSONKey(at offset: Int) throws -> [UInt8] {
        var string: [UInt8] = []
        for i in 0..<BSON_MAX_SIZE {
            if let b = self.getBytes(at: offset + i, length: 1) {
                if b[0] == 0 {
                    return string + [0x00]
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
        let typeByte = self.getInteger(at: position, as: UInt8.self) ?? BSONType.invalid.rawValue
        guard let type = BSONType(rawValue: typeByte), type != .invalid else {
            // Cannot get element type
            return .invalid
        }
        return type
    }
}
