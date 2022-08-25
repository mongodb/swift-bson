import NIOCore

extension String: BSONValue {
    internal static let extJSONTypeWrapperKeys: [String] = []

    /*
     * Initializes a `String` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `String`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not an `String`.
     */
    internal init?(fromExtJSON json: JSON, keyPath _: [String]) {
        switch json.value {
        case let .string(s):
            self = s
        default:
            return nil
        }
    }

    /// Converts this `String` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `String` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        JSON(.string(self))
    }

    internal static var bsonType: BSONType { .string }

    internal var bson: BSON { .string(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let length = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Cannot read string length")
        }
        guard length > 0 else {
            throw BSONError.InternalError(message: "String length is always >= 1 for null terminator")
        }
        guard let bytes = buffer.readBytes(length: Int(length)) else {
            throw BSONError.InternalError(message: "Cannot read \(length) bytes for string")
        }
        guard let nullTerm = bytes.last, nullTerm == 0 else {
            throw BSONError.InternalError(message: "String is not null terminated")
        }
        guard let string = String(bytes: bytes.dropLast(), encoding: .utf8) else {
            throw BSONError.InternalError(message: "Invalid UTF8")
        }
        return .string(string)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(Int32(self.utf8.count + 1), endianness: .little, as: Int32.self)
        buffer.writeBytes(self.utf8)
        buffer.writeInteger(0, as: UInt8.self)
    }
}
