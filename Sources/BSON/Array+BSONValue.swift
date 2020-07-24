import NIO

/// An extension of `Array` to represent the BSON array type.
extension Array: BSONValue where Element == BSON {
    /*
     * Initializes an `Array` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for an `Array`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value does not conform to the `Array` syntax.
     *
     * Throws:
     *   - `DecodingError` if elements within the array is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard case let .array(a) = json else {
            return nil
        }
        self = try a.enumerated().map { index, element in
            try BSON(fromExtJSON: element, keyPath: keyPath + [String(index)])
        }
    }

    internal static var bsonType: BSONType { .array }

    internal var bson: BSON { .array(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let doc = try BSONDocument.read(from: &buffer).documentValue else {
            throw BSONError.InternalError(message: "BSON Array cannot be read, failed to get documentValue")
        }
        return .array(doc.values)
    }

    internal func write(to buffer: inout ByteBuffer) {
        var array = BSONDocument()
        for (index, value) in self.enumerated() {
            array[String(index)] = value
        }
        array.write(to: &buffer)
    }
}
