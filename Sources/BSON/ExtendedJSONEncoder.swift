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

    /// The options set on the encoder.
    public struct Options {
        /// Either Canonical or Relaxed Extended JSON Format to encode to.
        public var mode: Mode = .relaxed
    }

    /// Initialize an `ExtendedJSONEncoder`.
    public init(options: ExtendedJSONEncoder.Options) {
        fatalError("unimplemented")
    }

    /// Encodes an instance of the Encodable Type `T` into Data representing ExtendedJSON.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/mongodb-extended-json/
    ///
    /// - Parameters:
    ///   - value: instance of Encodable type `T` which will be encoded.
    /// - Returns: Encoded representation of the `T` input as an instance of `Data` representing ExtendedJSON.
    /// - Throws: `EncodingError` if the value is corrupt or cannot be converted to valid ExtendedJSON.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        // Takes in any encodable type `T`, converts it to an instance of the `BSON` enum via the `BSONDecoder`.
        // The `BSON` is converted to an instance of the `JSON` enum via the `toRelaxedExtendedJSON`
        // or `toCanonicalExtendedJSON` methods on `BSONValue`s (depending on the `mode`).
        // The `JSON` is then passed through a `JSONEncoder` and outputted as `Data`.
        // T --> BSON --> JSON --> Data
        fatalError("unimplemented")
    }
}
