import Foundation
/// Decoder for ExtendedJSON
public class ExtendedJSONDecoder {
    /// Initialize a Decoder
    public init() {
        fatalError("unimplemented")
    }

    /// Takes in JSON as `Data` encoded with `.utf8` and runs it through a `JSONDecoder` to get an
    /// instance of the `JSON` enum. Then a `BSON` enum instance is created via the `JSON`.
    /// The `BSON is then passed through a `BSONDecoder` where it is outputted as a `T`
    ///
    /// Data --> JSON --> BSON --> T
    ///
    /// - Parameters:
    ///   - type: Codable type to decode the input into.
    ///   - data: `Data` which represents the `JSON` that will be decoded.
    /// - Returns: Decoded representation of the `JSON` input as an instance of T.
    /// - Throws:
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        fatalError("unimplemented")
    }
}
