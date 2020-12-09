import NIO

extension Double: BSONValue {
    internal static let extJSONTypeWrapperKeys: [String] = ["$numberDouble"]

    /*
     * Initializes a `Double` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Double`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not a `Double`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        switch json.value {
        case let .number(n):
            // relaxed extended JSON
            guard let num = Double(n) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Could not parse `Double` from \"\(n)\", " +
                        "input must be a 64-bit signed floating point as a decimal string"
                )
            }
            self = num
        case .object:
            // canonical extended JSON
            guard let value = try json.value.unwrapObject(withKey: "$numberDouble", keyPath: keyPath) else {
                return nil
            }
            guard
                let str = value.stringValue,
                let double = Double(str)
            else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Could not parse `Double` from \"\(value)\", " +
                        "input must be a 64-bit signed floating point as a decimal string"
                )
            }
            self = double
        default:
            return nil
        }
    }

    /// Helper function to make sure ExtendedJSON formatting matches Corpus Tests
    internal func formatForExtendedJSON() -> String {
        if self.isNaN {
            return "NaN"
        } else if self == Double.infinity {
            return "Infinity"
        } else if self == -Double.infinity {
            return "-Infinity"
        } else {
            return String(describing: self).uppercased()
        }
    }

    /// Converts this `Double` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        if self.isInfinite || self.isNaN {
            return self.toCanonicalExtendedJSON()
        } else {
            return JSON(.number(String(self)))
        }
    }

    /// Converts this `Double` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        ["$numberDouble": JSON(.string(self.formatForExtendedJSON()))]
    }

    internal static var bsonType: BSONType { .double }

    internal var bson: BSON { .double(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let data = buffer.readBytes(length: 8) else {
            throw BSONError.InternalError(message: "Cannot read 8 bytes")
        }
        var value = Double()
        let bytesCopied = withUnsafeMutableBytes(of: &value) { data.copyBytes(to: $0) }
        guard bytesCopied == MemoryLayout.size(ofValue: value) else {
            throw BSONError.InternalError(message: "Cannot initialize Double from bytes \(data)")
        }
        return .double(value)
    }

    internal func write(to buffer: inout ByteBuffer) {
        let data = withUnsafeBytes(of: self) { [UInt8]($0) }
        buffer.writeBytes(data)
    }
}
