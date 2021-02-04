import ExtrasJSON
import Foundation
import NIO

/// Facilitates the encoding of `Encodable` values into ExtendedJSON.
public class ExtendedJSONEncoder {
    /// An enum representing one of the two supported string formats based on the JSON standard
    /// that describe how to represent BSON documents in JSON using standard JSON types and/or type wrapper objects.
    public enum Mode {
        /// Canonical Extended JSON Format: Emphasizes type preservation
        /// at the expense of readability and interoperability.
        case canonical

        /// Relaxed Extended JSON Format: Emphasizes readability and interoperability
        /// at the expense of type preservation.
        case relaxed
    }

    /// Determines whether to encode to canonical or relaxed extended JSON. Default is relaxed.
    public var mode: Mode = .relaxed

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Initialize an `ExtendedJSONEncoder`.
    public init() {}

    private func encodeBytes<T: Encodable>(_ value: T) throws -> [UInt8] {
        // T --> BSON --> JSONValue --> Data
        // Takes in any encodable type `T`, converts it to an instance of the `BSON` enum via the `BSONDecoder`.
        // The `BSON` is converted to an instance of the `JSON` enum via the `toRelaxedExtendedJSON`
        // or `toCanonicalExtendedJSON` methods on `BSONValue`s (depending on the `mode`).
        // The `JSON` is then passed through a `JSONEncoder` and outputted as `Data`.
        let encoder = BSONEncoder()
        encoder.userInfo = self.userInfo
        let bson: BSON = try encoder.encodeFragment(value)

        let json: JSON
        switch self.mode {
        case .canonical:
            json = bson.bsonValue.toCanonicalExtendedJSON()
        case .relaxed:
            json = bson.bsonValue.toRelaxedExtendedJSON()
        }

        var bytes: [UInt8] = []
        json.value.appendBytes(to: &bytes)
        return bytes
    }

    /// Encodes an instance of the Encodable Type `T` into Data representing canonical or relaxed extended JSON.
    /// The value of `self.mode` will determine which format is used. If it is not set explicitly, relaxed will be used.
    ///
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/mongodb-extended-json/
    ///
    /// - Parameters:
    ///   - value: instance of Encodable type `T` which will be encoded.
    /// - Returns: Encoded representation of the `T` input as an instance of `Data` representing ExtendedJSON.
    /// - Throws: `EncodingError` if the value is corrupt or cannot be converted to valid ExtendedJSON.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try Data(self.encodeBytes(value))
    }

    /// Encodes an instance of the Encodable Type `T` into a `ByteBuffer` representing canonical or relaxed extended
    /// JSON. The value of `self.mode` will determine which format is used. If it is not set explicitly, relaxed will
    /// be used.
    ///
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/mongodb-extended-json/
    ///
    /// - Parameters:
    ///   - value: instance of Encodable type `T` which will be encoded.
    /// - Returns: Encoded representation of the `T` input as an instance of `ByteBuffer` representing ExtendedJSON.
    /// - Throws: `EncodingError` if the value is corrupt or cannot be converted to valid ExtendedJSON.
    public func encodeBuffer<T: Encodable>(_ value: T) throws -> ByteBuffer {
        try BSON_ALLOCATOR.buffer(bytes: self.encodeBytes(value))
    }
}
