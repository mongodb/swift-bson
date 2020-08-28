import NIO

extension Bool: BSONValue {
    /*
     * Initializes a `Bool` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Bool`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not a `Bool`.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) {
        switch json {
        case let .bool(b):
            // canonical or relaxed extended JSON
            self = b
        default:
            return nil
        }
    }

    /// Converts this `Bool` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `Bool` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        .bool(self)
    }

    internal static var bsonType: BSONType { .bool }

    internal var bson: BSON { .bool(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(as: UInt8.self) else {
            throw BSONError.InternalError(message: "Could not read Bool")
        }
        guard value == 0 || value == 1 else {
            throw BSONError.InternalError(message: "Bool must be 0 or 1, found:\(value)")
        }
        return .bool(value == 0 ? false : true)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeBytes([self ? 1 : 0])
    }
}
