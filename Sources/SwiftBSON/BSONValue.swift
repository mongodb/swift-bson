import NIOCore

internal protocol BSONValue: Codable, BSONRepresentable {
    /// The `BSONType` associated with this value.
    static var bsonType: BSONType { get }

    /// A `BSON` corresponding to this `BSONValue`.
    var bson: BSON { get }

    /// The `$`-prefixed keys that indicate an object is an extended JSON object wrapper
    /// for this `BSONValue`. (e.g. for Int32, this value is ["$numberInt"]).
    static var extJSONTypeWrapperKeys: [String] { get }

    /// The `$`-prefixed keys that indicate an object may be a legacy extended JSON object wrapper.
    /// Because these keys can conflict with query operators (e.g. "$regex"), they are not always part of
    /// an object wrapper and may sometimes be parsed as normal BSON.
    static var extJSONLegacyTypeWrapperKeys: [String] { get }

    /// Initializes a corresponding `BSON` from the provided `ByteBuffer`,
    /// moving the buffer's readerIndex forward to the byte beyond the end
    /// of this value.
    static func read(from buffer: inout ByteBuffer) throws -> BSON

    /// Writes this value's BSON byte representation to the provided ByteBuffer.
    func write(to buffer: inout ByteBuffer) throws

    /// Initializes a corresponding `BSONValue` from the provided extendedJSON.
    init?(fromExtJSON json: JSON, keyPath: [String]) throws

    /// Converts this `BSONValue` to a corresponding `JSON` in relaxed extendedJSON format.
    func toRelaxedExtendedJSON() -> JSON

    /// Converts this `BSONValue` to a corresponding `JSON` in canonical extendedJSON format.
    func toCanonicalExtendedJSON() -> JSON

    /// Determines if this `BSONValue` was constructed from valid BSON, throwing if it was not.
    /// For most `BSONValue`s, this is a no-op.
    func validate() throws
}

/// Convenience extension to get static bsonType from an instance
extension BSONValue {
    internal static var extJSONLegacyTypeWrapperKeys: [String] { [] }

    internal var bsonType: BSONType {
        Self.bsonType
    }

    /// Default `Decodable` implementation that throws an error if executed with non-`BSONDecoder`.
    ///
    /// BSON types' `Deodable` conformance currently only works with `BSONDecoder`, but in the future will be able
    /// to work with any decoder (e.g. `JSONDecoder`).
    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    /// Default `Encodable` implementation that throws an error if executed with non-`BSONEncoder`.
    ///
    /// BSON types' `Encodable` conformance currently only works with `BSONEncoder`, but in the future will be able
    /// to work with any encoder (e.g. `JSONEncoder`).
    public func encode(to encoder: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: encoder.codingPath)
    }

    internal func validate() throws {}
}

/// The possible types of BSON values and their corresponding integer values.
public enum BSONType: UInt8 {
    /// An invalid type
    case invalid = 0x00
    /// 64-bit binary floating point
    case double = 0x01
    /// UTF-8 string
    case string = 0x02
    /// BSON document
    case document = 0x03
    /// Array
    case array = 0x04
    /// Binary data
    case binary = 0x05
    /// Undefined value - deprecated
    case undefined = 0x06
    /// A MongoDB ObjectID.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/method/ObjectId/
    case objectID = 0x07
    /// A boolean
    case bool = 0x08
    /// UTC datetime, stored as UTC milliseconds since the Unix epoch
    case datetime = 0x09
    /// Null value
    case null = 0x0A
    /// A regular expression
    case regex = 0x0B
    /// A database pointer - deprecated
    case dbPointer = 0x0C
    /// Javascript code
    case code = 0x0D
    /// A symbol - deprecated
    case symbol = 0x0E
    /// JavaScript code w/ scope
    case codeWithScope = 0x0F
    /// 32-bit integer
    case int32 = 0x10
    /// Special internal type used by MongoDB replication and sharding
    case timestamp = 0x11
    /// 64-bit integer
    case int64 = 0x12
    /// 128-bit decimal floating point
    case decimal128 = 0x13
    /// Special type which compares lower than all other possible BSON element values
    case minKey = 0xFF
    /// Special type which compares higher than all other possible BSON element values
    case maxKey = 0x7F
}
