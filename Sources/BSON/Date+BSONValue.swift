import Foundation
import NIO

extension Date: BSONValue {
    /*
     * Initializes a `Date` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Date`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value does not conform to the `Date` syntax.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        guard let (value, _) = try json.isObjectWithSingleKey(key: "$date", keyPath: keyPath) else {
            return nil
        }
        switch value {
        case .object:
            // canonical extended JSON
            guard let int = try Int64(fromExtJSON: value, keyPath: keyPath) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(value) to be canonical extended JSON representing a " +
                        "64-bit signed integer giving millisecs relative to the epoch, as a string"
                )
            }
            self = Date(msSinceEpoch: int)
        case let .string(s):
            // relaxed extended JSON
            guard let date = ExtendedJSONDecoder.extJSONDateFormatter.date(from: s) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(s) to be an ISO-8601 Internet Date/Time Format" +
                        " with maximum time precision of milliseconds as a string"
                )
            }
            self = date
        default:
            return nil
        }
    }

    internal static var bsonType: BSONType { .datetime }

    internal var bson: BSON { .datetime(self) }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    internal var msSinceEpoch: Int64 { Int64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    internal init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let ms = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Unable to read UTC datetime (int64)")
        }
        return .datetime(Date(msSinceEpoch: ms))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.msSinceEpoch, endianness: .little, as: Int64.self)
    }
}
