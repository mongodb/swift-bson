import NIO

public struct BSONTimestamp: BSONValue, Equatable, Hashable {
    internal static var bsonType: BSONType { .timestamp }
    internal var bson: BSON { .timestamp(self) }

    /// A timestamp representing seconds since the Unix epoch.
    public let timestamp: UInt32
    /// An incrementing ordinal for operations within a given second.
    public let increment: UInt32

    /// Initializes a new  `BSONTimestamp` with the provided `timestamp` and `increment` values.
    public init(timestamp: UInt32, inc: UInt32) {
        self.timestamp = timestamp
        self.increment = inc
    }

    /*
     * Initializes a `BSONTimestamp` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Timestamp`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not a `Timestamp`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard let (value, _) = try json.isObjectWithSingleKey(key: "$timestamp", keyPath: keyPath) else {
            return nil
        }
        guard let timestampObj = value.objectValue else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected \(value) to be an object"
            )
        }
        guard
            timestampObj.count == 2,
            let t = timestampObj["t"],
            let i = timestampObj["i"]
        else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected only \"t\" and \"i\" keys, " +
                    "found \(timestampObj.keys.count) keys within \"$timestamp\": \(timestampObj.keys)"
            )
        }
        guard
            let tDouble = t.doubleValue,
            let tInt = UInt32(exactly: tDouble),
            let iDouble = i.doubleValue,
            let iInt = UInt32(exactly: iDouble)
        else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Could not parse `BSONTimestamp` from \"\(timestampObj)\", " +
                    "values for \"t\" and \"i\" must be 32-bit positive integers"
            )
        }
        self = BSONTimestamp(timestamp: tInt, inc: iInt)
    }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let increment = buffer.readInteger(endianness: .little, as: UInt32.self) else {
            throw BSONError.InternalError(message: "Cannot read increment from BSON timestamp")
        }
        guard let timestamp = buffer.readInteger(endianness: .little, as: UInt32.self) else {
            throw BSONError.InternalError(message: "Cannot read timestamp from BSON timestamp")
        }
        return .timestamp(BSONTimestamp(timestamp: timestamp, inc: increment))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.increment, endianness: .little, as: UInt32.self)
        buffer.writeInteger(self.timestamp, endianness: .little, as: UInt32.self)
    }
}
