import ExtrasJSON
import Foundation

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

    /// The output formatting options that determine the readability, size, and element order of an encoded JSON object.
    public struct OutputFormatting: OptionSet {
        internal let value: JSONEncoder.OutputFormatting

        public var rawValue: UInt { self.value.rawValue }

        public init(rawValue: UInt) {
            self.value = JSONEncoder.OutputFormatting(rawValue: rawValue)
        }

        internal init(_ value: JSONEncoder.OutputFormatting) {
            self.value = value
        }

        /// Produce human-readable JSON with indented output.
        public static let prettyPrinted = OutputFormatting(.prettyPrinted)

        /// Produce JSON with dictionary keys sorted in lexicographic order.
        public static let sortedKeys = OutputFormatting(.sortedKeys)
    }

    /// Determines whether to encode to canonical or relaxed extended JSON. Default is relaxed.
    public var mode: Mode = .relaxed

    /// Contextual user-provided information for use during encoding.
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// A value that determines the readability, size, and element order of the encoded JSON object.
    public var outputFormatting: ExtendedJSONEncoder.OutputFormatting = []

    /// Initialize an `ExtendedJSONEncoder`.
    public init() {}

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

        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = self.outputFormatting.value
        return try jsonEncoder.encode(json)
    }
}
