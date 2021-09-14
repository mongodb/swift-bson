import NIO

extension ByteBuffer {
    /// Write null terminated UTF-8 string to ByteBuffer starting at writerIndex
    @discardableResult
    internal mutating func writeCString(_ string: String) throws -> Int {
        guard string.isValidCString else {
            throw BSONError.InvalidArgumentError(
                message: "C string cannot contain embedded null bytes - found \"\(string)\""
            )
        }
        let written = self.writeString(string + "\0")
        return written
    }

    /// Attempts to read null terminated UTF-8 string from ByteBuffer starting at the readerIndex
    internal mutating func readCString() throws -> String {
        var string: [UInt8] = []
        for _ in 0..<Int(BSON_MAX_SIZE) {
            guard let b = self.readInteger(endianness: .little, as: UInt8.self) else {
                throw BSONError.InternalError(message: "Failed to read CString, unable to read byte from \(self)")
            }

            guard b != 0 else {
                guard let s = String(bytes: string, encoding: .utf8) else {
                    throw BSONError.InternalError(message: "Unable to decode utf8 string from \(string)")
                }
                return s
            }

            string.append(b)
        }
        throw BSONError.InternalError(message: "Failed to read CString, possibly missing null terminator?")
    }
}
extension String {
    internal var isValidCString: Bool {
        // C strings cannot contain embedded null bytes.
        !self.utf8.contains(0)
    }
}
