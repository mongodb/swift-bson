import Foundation
import NIO

/// A struct to represent the BSON Binary type.
public struct BSONBinary: Equatable, Hashable {
    /// The binary data.
    public let data: ByteBuffer

    /// The binary subtype for this data.
    public let subtype: Subtype

    /// Subtypes for BSON Binary values.
    public struct Subtype: Equatable, Hashable, RawRepresentable, Codable {
        // swiftlint:disable force_unwrapping
        /// Generic binary subtype
        public static let generic = Subtype(rawValue: 0x00)!
        /// A function
        public static let function = Subtype(rawValue: 0x01)!
        /// Binary (old)
        public static let binaryDeprecated = Subtype(rawValue: 0x02)!
        /// UUID (old)
        public static let uuidDeprecated = Subtype(rawValue: 0x03)!
        /// UUID (RFC 4122)
        public static let uuid = Subtype(rawValue: 0x04)!
        /// MD5
        public static let md5 = Subtype(rawValue: 0x05)!
        /// Encrypted BSON value
        public static let encryptedValue = Subtype(rawValue: 0x06)!
        // swiftlint:enable force_unwrapping

        /// Subtype indicator value
        public let rawValue: UInt8

        /// Initializes a `Subtype` with a custom value.
        /// Returns nil if rawValue within reserved range [0x07, 0x80).
        public init?(rawValue: UInt8) {
            guard !(rawValue > 0x06 && rawValue < 0x80) else {
                return nil
            }
            self.rawValue = rawValue
        }

        /// Initializes a `Subtype` with a custom value. This value must be in the range 0x80-0xFF.
        /// - Throws:
        ///   - `BSONError.InvalidArgumentError` if value passed is outside of the range 0x80-0xFF
        public static func userDefined(_ value: Int) throws -> Subtype {
            guard let byteValue = UInt8(exactly: value) else {
                throw BSONError.InvalidArgumentError(message: "Cannot represent \(value) as UInt8")
            }
            guard byteValue >= 0x80 else {
                throw BSONError.InvalidArgumentError(
                    message: "userDefined value must be greater than or equal to 0x80 got \(byteValue)"
                )
            }
            guard let subtype = Subtype(rawValue: byteValue) else {
                throw BSONError.InvalidArgumentError(message: "Cannot represent \(byteValue) as Subtype")
            }
            return subtype
        }
    }

    /// Initializes a `BSONBinary` instance from a `UUID`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if a `BSONBinary` cannot be constructed from this UUID.
    public init(from uuid: UUID) throws {
        let uuidt = uuid.uuid

        let uuidData = Data([
            uuidt.0, uuidt.1, uuidt.2, uuidt.3,
            uuidt.4, uuidt.5, uuidt.6, uuidt.7,
            uuidt.8, uuidt.9, uuidt.10, uuidt.11,
            uuidt.12, uuidt.13, uuidt.14, uuidt.15
        ])

        self = try BSONBinary(data: uuidData, subtype: BSONBinary.Subtype.uuid)
    }

    /// Initializes a `BSONBinary` instance from a `Data` object and a `Subtype` subtype.
    /// This will always create a copy of the data.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if the provided data is incompatible with the specified subtype.
    public init(data: Data, subtype: Subtype) throws {
        var buffer = BSON_ALLOCATOR.buffer(capacity: data.count)
        buffer.writeBytes(data)
        self = try BSONBinary(buffer: buffer, subtype: subtype)
    }

    internal init(bytes: [UInt8], subtype: Subtype) throws {
        var buffer = BSON_ALLOCATOR.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        self = try BSONBinary(buffer: buffer, subtype: subtype)
    }

    internal init(buffer: ByteBuffer, subtype: Subtype) throws {
        if [Subtype.uuid, Subtype.uuidDeprecated].contains(subtype) && buffer.readableBytes != 16 {
            throw BSONError.InvalidArgumentError(
                message:
                "Binary data with UUID subtype must be 16 bytes, but buffer has \(buffer.readableBytes) bytes"
            )
        }

        self.subtype = subtype
        self.data = buffer
    }

    /// Initializes a `BSONBinary` instance from a base64 `String` and a `Subtype`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if the base64 `String` is invalid or if the provided data is
    ///     incompatible with the specified subtype.
    public init(base64: String, subtype: Subtype) throws {
        guard let dataObj = Data(base64Encoded: base64) else {
            throw BSONError.InvalidArgumentError(
                message:
                "failed to create Data object from invalid base64 string \(base64)"
            )
        }
        try self.init(data: dataObj, subtype: subtype)
    }

    /// Converts this `BSONBinary` instance to a `UUID`.
    /// - Throws:
    ///   - `BSONError.InvalidArgumentError` if a non-UUID subtype is set on this `BSONBinary`.
    public func toUUID() throws -> UUID {
        guard [Subtype.uuid, Subtype.uuidDeprecated].contains(self.subtype) else {
            throw BSONError.InvalidArgumentError(
                message: "Expected a UUID binary subtype, got subtype \(self.subtype) instead."
            )
        }

        guard let data = self.data.getBytes(at: 0, length: 16) else {
            throw BSONError.InternalError(message: "Unable to read 16 bytes from Binary.data")
        }

        let uuid: uuid_t = (
            data[0], data[1], data[2], data[3],
            data[4], data[5], data[6], data[7],
            data[8], data[9], data[10], data[11],
            data[12], data[13], data[14], data[15]
        )

        return UUID(uuid: uuid)
    }
}

extension BSONBinary: BSONValue {
    /*
     * Initializes a `Binary` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `Binary`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value does not conform to the `Binary` syntax.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        if let uuidJSON = try json.unwrapObject(withKey: "$uuid", keyPath: keyPath) {
            guard let uuidString = uuidJSON.stringValue else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected value for key $uuid \"\(uuidJSON)\" to be a string"
                        + " but got some other value"
                )
            }
            guard let uuid = UUID(uuidString: uuidString) else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Invalid UUID string: \(uuidString)"
                )
            }

            do {
                self = try BSONBinary(from: uuid)
                return
            } catch {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: error.localizedDescription
                )
            }
        }

        // canonical and relaxed extended JSON
        guard let binary = try json.unwrapObject(withKey: "$binary", keyPath: keyPath) else {
            return nil
        }
        guard
            let (base64, subTypeInput) = try binary.unwrapObject(withKeys: "base64", "subType", keyPath: keyPath)
        else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Missing \"base64\" or \"subType\" in \(binary)"
            )
        }
        guard let base64Str = base64.stringValue else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Could not parse `base64` from \"\(base64)\", " +
                    "input must be a base64-encoded (with padding as =) payload as a string"
            )
        }
        guard
            let subTypeStr = subTypeInput.stringValue,
            let subTypeInt = UInt8(subTypeStr, radix: 16),
            let subType = Subtype(rawValue: subTypeInt)
        else {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: "Could not parse `SubType` from \"\(subTypeInput)\", " +
                    "input must be a BSON binary type as a one- or two-character hex string"
            )
        }
        do {
            self = try BSONBinary(base64: base64Str, subtype: subType)
        } catch {
            throw DecodingError._extendedJSONError(
                keyPath: keyPath,
                debugDescription: error.localizedDescription
            )
        }
    }

    /// Converts this `BSONBinary` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.toCanonicalExtendedJSON()
    }

    /// Converts this `BSONBinary` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        [
            "$binary": [
                "base64": .string(Data(self.data.readableBytesView).base64EncodedString()),
                "subType": .string(String(format: "%02x", self.subtype.rawValue))
            ]
        ]
    }

    internal static var bsonType: BSONType { .binary }

    internal var bson: BSON { .binary(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let byteLength = buffer.readInteger(endianness: .little, as: Int32.self), byteLength >= 0 else {
            throw BSONError.InternalError(message: "Cannot read BSONBinary's byte length")
        }
        guard let subtypeByte = buffer.readInteger(as: UInt8.self) else {
            throw BSONError.InternalError(message: "Cannot read BSONBinary's subtype")
        }
        guard let subtype = Subtype(rawValue: subtypeByte) else {
            throw BSONError.InternalError(message: "Cannot create subtype for 0x\(String(subtypeByte, radix: 16))")
        }

        guard subtype != .binaryDeprecated else {
            guard let oldSize = buffer.readInteger(endianness: .little, as: Int32.self) else {
                throw BSONError.InternalError(message: "Cannot read BSONBinary's old byte length")
            }
            guard oldSize == (byteLength - 4) else {
                throw BSONError.InternalError(message: "Invalid size for BSONBinary subtype: \(subtype)")
            }
            guard let bytes = buffer.readBytes(length: Int(oldSize)) else {
                throw BSONError.InternalError(message: "Cannot read \(oldSize) from buffer for BSONBinary")
            }
            return .binary(try BSONBinary(bytes: bytes, subtype: subtype))
        }

        guard let bytes = buffer.readBytes(length: Int(byteLength)) else {
            throw BSONError.InternalError(message: "Cannot read \(byteLength) from buffer for BSONBinary")
        }
        return .binary(try BSONBinary(bytes: bytes, subtype: subtype))
    }

    internal func write(to buffer: inout ByteBuffer) {
        if self.subtype == .binaryDeprecated {
            buffer.writeInteger(Int32(self.data.readableBytes + 4), endianness: .little, as: Int32.self)
            buffer.writeInteger(self.subtype.rawValue, as: UInt8.self)
            buffer.writeInteger(Int32(self.data.readableBytes), endianness: .little, as: Int32.self)
        } else {
            buffer.writeInteger(Int32(self.data.readableBytes), endianness: .little, as: Int32.self)
            buffer.writeInteger(self.subtype.rawValue, as: UInt8.self)
        }
        buffer.writeBytes(self.data.readableBytesView)
    }
}
