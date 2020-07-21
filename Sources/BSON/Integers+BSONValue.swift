import NIO

extension Int32: BSONValue {
    /*
     * Initializes an `Int32` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for an `Int32`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not an `Int32`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        switch json {
        case let .number(n):
            // relaxed extended JSON
            guard let int = Int32(exactly: n) else {
                return nil
            }
            self = int
        case .object:
            // canonical extended JSON
            guard let value = try json.onlyHasKey(key: "$numberInt", keyPath: keyPath) else {
                return nil
            }
            guard
                let str = value.stringValue,
                let int = Int32(str)
            else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Could not parse `Int32` from \"\(value)\", " +
                        "input must be a 32-bit signed integer as a string."
                )
            }
            self = int
        default:
            return nil
        }
    }

    internal static var bsonType: BSONType { .int32 }

    internal var bson: BSON { .int32(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 32-bit integer")
        }
        return .int32(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int32.self)
    }
}

extension Int64: BSONValue {
    /*
     * Initializes an `Int64` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for an `Int64`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not an `Int64`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        switch json {
        case let .number(n):
            // relaxed extended JSON
            guard let int = Int64(exactly: n) else {
                return nil
            }
            self = int
        case .object:
            // canonical extended JSON
            guard let value = try json.onlyHasKey(key: "$numberLong", keyPath: keyPath) else {
                return nil
            }
            guard
                let str = value.stringValue,
                let int = Int64(str)
            else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription:
                    "Could not parse `Int64` from \"\(value)\", input must be a 64-bit signed integer as a string."
                )
            }
            self = int
        default:
            return nil
        }
    }

    internal static var bsonType: BSONType { .int64 }

    internal var bson: BSON { .int64(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let value = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Not enough bytes remain to read 64-bit integer")
        }
        return .int64(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self, endianness: .little, as: Int64.self)
    }
}
