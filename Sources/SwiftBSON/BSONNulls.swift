import NIOCore

/// A struct to represent the BSON null type.
internal struct BSONNull: BSONValue, Equatable {
    internal static let extJSONTypeWrapperKeys: [String] = []

    /*
     * Initializes a `BSONNull` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `BSONNull`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not `null`.
     *
     */
    internal init?(fromExtJSON json: JSON, keyPath _: [String]) {
        switch json.value {
        case .null:
            // canonical or relaxed extended JSON
            self = BSONNull()
        default:
            return nil
        }
    }

    /// Converts this `BSONNull` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `BSONNull` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        JSON(.null)
    }

    internal static var bsonType: BSONType { .null }

    internal var bson: BSON { .null }

    /// Initializes a new `BSONNull` instance.
    internal init() {}

    internal static func read(from _: inout ByteBuffer) throws -> BSON {
        .null
    }

    internal func write(to _: inout ByteBuffer) {
        // no-op
    }
}

/// A struct to represent the BSON undefined type.
internal struct BSONUndefined: BSONValue, Equatable {
    internal static let extJSONTypeWrapperKeys: [String] = ["$undefined"]

    /*
     * Initializes a `BSONUndefined` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `BSONUndefined`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not `{"$undefined": true}`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard let value = try json.value.unwrapObject(withKey: "$undefined", keyPath: keyPath) else {
            return nil
        }
        guard value.boolValue == true else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected \(value) to be \"true\""
            )
        }
        self = BSONUndefined()
    }

    /// Converts this `BSONUndefined` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `BSONUndefined` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$undefined": true]
    }

    internal static var bsonType: BSONType { .undefined }

    internal var bson: BSON { .undefined }

    /// Initializes a new `BSONUndefined` instance.
    internal init() {}

    internal static func read(from _: inout ByteBuffer) throws -> BSON {
        .undefined
    }

    internal func write(to _: inout ByteBuffer) {
        // no-op
    }
}

/// A struct to represent the BSON MinKey type.
internal struct BSONMinKey: BSONValue, Equatable {
    internal static let extJSONTypeWrapperKeys: [String] = ["$minKey"]

    /*
     * Initializes a `BSONMinKey` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `BSONMinKey`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not `{"$minKey": 1}`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard let value = try json.value.unwrapObject(withKey: "$minKey", keyPath: keyPath) else {
            return nil
        }
        guard value.doubleValue == 1 else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected \(value) to be \"1\""
            )
        }
        self = BSONMinKey()
    }

    /// Converts this `BSONMinKey` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `BSONMinKey` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$minKey": 1]
    }

    internal static var bsonType: BSONType { .minKey }

    internal var bson: BSON { .minKey }

    /// Initializes a new `MinKey` instance.
    internal init() {}

    internal static func read(from _: inout ByteBuffer) throws -> BSON {
        .minKey
    }

    internal func write(to _: inout ByteBuffer) {
        // no-op
    }
}

/// A struct to represent the BSON MinKey type.
internal struct BSONMaxKey: BSONValue, Equatable {
    internal static let extJSONTypeWrapperKeys: [String] = ["$maxKey"]

    /*
     * Initializes a `BSONMaxKey` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `BSONMaxKey`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not `{"$minKey": 1}`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        // canonical and relaxed extended JSON
        guard let value = try json.value.unwrapObject(withKey: "$maxKey", keyPath: keyPath) else {
            return nil
        }
        guard value.doubleValue == 1 else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Expected \(value) to be \"1\""
            )
        }
        self = BSONMaxKey()
    }

    /// Converts this `BSONMaxKey` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `BSONMaxKey` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$maxKey": 1]
    }

    internal static var bsonType: BSONType { .maxKey }

    internal var bson: BSON { .maxKey }

    /// Initializes a new `MaxKey` instance.
    internal init() {}

    internal static func read(from _: inout ByteBuffer) throws -> BSON {
        .maxKey
    }

    internal func write(to _: inout ByteBuffer) {
        // no-op
    }
}
