import Foundation
/// Facilitates the encoding of `Encodable` values into ExtendedJSON.
public class ExtendedJSONEncoder {
    internal enum extendedJSONMode {
        case canonical
        case relaxed
    }

    /// Initialize an `ExtendedJSONEncoder`.
    public init() {
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
