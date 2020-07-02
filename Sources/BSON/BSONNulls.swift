import NIO

/// A struct to represent the BSON null type.
internal struct BSONNull: BSONValue, Equatable {
    internal static var bsonType: BSONType { .null }

    internal var bson: BSON { .null }

    /// Initializes a new `BSONNull` instance.
    internal init() {}

    internal static func read(from: inout ByteBuffer) throws -> BSON {
        .null
    }

    internal func write(to: inout ByteBuffer) {
        // no-op
    }
    
    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}

/// A struct to represent the BSON undefined type.
internal struct BSONUndefined: BSONValue, Equatable {
    internal static var bsonType: BSONType { .undefined }

    internal var bson: BSON { .undefined }

    /// Initializes a new `BSONUndefined` instance.
    internal init() {}

    internal static func read(from: inout ByteBuffer) throws -> BSON {
        .undefined
    }

    internal func write(to: inout ByteBuffer) {
        // no-op
    }

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}

/// A struct to represent the BSON MinKey type.
internal struct BSONMinKey: BSONValue, Equatable {
    internal static var bsonType: BSONType { .minKey }

    internal var bson: BSON { .minKey }

    /// Initializes a new `MinKey` instance.
    internal init() {}

    internal static func read(from: inout ByteBuffer) throws -> BSON {
        .minKey
    }

    internal func write(to: inout ByteBuffer) {
        // no-op
    }

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}

/// A struct to represent the BSON MinKey type.
internal struct BSONMaxKey: BSONValue, Equatable {
    internal static var bsonType: BSONType { .maxKey }

    internal var bson: BSON { .maxKey }

    /// Initializes a new `MaxKey` instance.
    internal init() {}

    internal static func read(from: inout ByteBuffer) throws -> BSON {
        .maxKey
    }

    internal func write(to: inout ByteBuffer) {
        // no-op
    }

    internal init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    internal func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}
