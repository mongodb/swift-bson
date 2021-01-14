import ExtrasJSON
import Foundation

/// Enum representing a BSON value.
/// - SeeAlso: bsonspec.org
public enum BSON {
    /// A BSON document.
    case document(BSONDocument)

    /// A BSON int32.
    case int32(Int32)

    /// A BSON int64.
    case int64(Int64)

    /// A BSON Decimal128
    case decimal128(BSONDecimal128)

    /// A BSON Array
    indirect case array([BSON])

    /// A BSON Boolean
    case bool(Bool)

    /// A BSON UTC datetime.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/bson-types/#date
    case datetime(Date)

    /// A BSON double.
    case double(Double)

    /// A BSON string.
    case string(String)

    /// A BSON Symbol
    case symbol(BSONSymbol)

    /// A BSON Timestamp
    case timestamp(BSONTimestamp)

    /// A BSON Binary
    case binary(BSONBinary)

    /// A BSON Regex
    case regex(BSONRegularExpression)

    /// A BSON ObjectID
    case objectID(BSONObjectID = BSONObjectID())

    /// A BSON DBPointer
    case dbPointer(BSONDBPointer)

    /// A BSON Code
    case code(BSONCode)

    /// A BSON Code with Scope
    case codeWithScope(BSONCodeWithScope)

    /// A BSON Null
    case null

    /// A BSON Undefined
    case undefined

    /// A BSON MinKey
    case minKey

    /// A BSON MaxKey
    case maxKey

    /// Initialize a `BSON` from an integer. On 64-bit systems, this will result in an `.int64`. On 32-bit systems,
    /// this will result in an `.int32`.
    public init(_ int: Int) {
        if MemoryLayout<Int>.size == 4 {
            self = .int32(Int32(int))
        } else {
            self = .int64(Int64(int))
        }
    }

    /// Initialize a `BSON` from ExtendedJSON.
    /// This is not as performant as decoding via ExtendedJSONDecoder and should only be used scalar values.
    ///
    /// Parameters:
    ///   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for any `BSONValue`.
    ///   - `keyPath`: an array of `Strings`s containing the enclosing JSON keys of the current json being passed in.
    ///              This is used for error messages.
    ///
    /// Throws:
    ///   - `DecodingError` if `json` is malformatted extended json
    internal init(fromExtJSON json: JSON, keyPath: [String]) throws {
        // Spec requires that we try int32, try int64, then try double for decoding numbers
        if let int32 = try Int32(fromExtJSON: json, keyPath: keyPath) {
            self = int32.bson
            return
        }
        if let int64 = try Int64(fromExtJSON: json, keyPath: keyPath) {
            self = int64.bson
            return
        }
        for bsonType in BSON.allBSONTypes.values {
            guard bsonType != Int32.self && bsonType != Int64.self && bsonType != BSONDocument.self else {
                continue
            }
            if let value = try bsonType.init(fromExtJSON: json, keyPath: keyPath) {
                self = value.bson
                return
            }
        }
        // Document accepts any JSON object so it should be tried after all the more specific BSON types are tried
        guard let doc = try BSONDocument(fromExtJSON: json, keyPath: keyPath) else {
            throw BSONError.InternalError(message: "Could not parse BSON from \(json)")
        }
        self = doc.bson
    }

    /// Converts this `BSON` to a corresponding `JSON` in relaxed extendedJSON format.
    internal func toRelaxedExtendedJSON() -> JSON {
        self.bsonValue.toRelaxedExtendedJSON()
    }

    /// Converts this `BSON` to a corresponding `JSON` in canonical extendedJSON format.
    internal func toCanonicalExtendedJSON() -> JSON {
        self.bsonValue.toCanonicalExtendedJSON()
    }

    /// Get the `BSONType` of this `BSON`.
    public var type: BSONType {
        self.bsonValue.bsonType
    }
}

/// Value getters
extension BSON {
    /// If this `BSON` is an `.int32`, return it as an `Int32`. Otherwise, return nil.
    public var int32Value: Int32? {
        guard case let .int32(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is an `.int64`, return it as an `Int64`. Otherwise, return nil.
    public var int64Value: Int64? {
        guard case let .int64(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is an `.decimal128`, return it as an `BSONDecimal128`. Otherwise, return nil.
    public var decimal128Value: BSONDecimal128? {
        guard case let .decimal128(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is a `.document`, return it as a `BSONDocument`. Otherwise, return nil.
    public var documentValue: BSONDocument? {
        guard case let .document(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.array`, return it as a `[BSON]`. Otherwise, return nil.
    public var arrayValue: [BSON]? {
        guard case let .array(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.bool`, return it as a `Bool`. Otherwise, return nil.
    public var boolValue: Bool? {
        guard case let .bool(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.date`, return it as a `Date`. Otherwise, return nil.
    public var dateValue: Date? {
        guard case let .datetime(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.double`, return it as a `Double`. Otherwise, return nil.
    public var doubleValue: Double? {
        guard case let .double(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.string`, return it as a `String`. Otherwise, return nil.
    public var stringValue: String? {
        guard case let .string(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.symbol`, return it as a `BSONSymbol`. Otherwise, return nil.
    public var symbolValue: BSONSymbol? {
        guard case let .symbol(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.timestamp`, return it as a `BSONTimestamp`. Otherwise, return nil.
    public var timestampValue: BSONTimestamp? {
        guard case let .timestamp(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.binary`, return it as a `BSONBinary`. Otherwise, return nil.
    public var binaryValue: BSONBinary? {
        guard case let .binary(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.regex`, return it as a `BSONRegularExpression`. Otherwise, return nil.
    public var regexValue: BSONRegularExpression? {
        guard case let .regex(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.objectID`, return it as a `BSONObjectID`. Otherwise, return nil.
    public var objectIDValue: BSONObjectID? {
        guard case let .objectID(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.dbPointer`, return it as a `BSONDBPointer`. Otherwise, return nil.
    public var dbPointerValue: BSONDBPointer? {
        guard case let .dbPointer(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.code`, return it as a `BSONCode`. Otherwise, return nil.
    public var codeValue: BSONCode? {
        guard case let .code(d) = self else {
            return nil
        }
        return d
    }

    /// If this `BSON` is a `.codeWithScope`, return it as a `BSONCodeWithScope`. Otherwise, return nil.
    public var codeWithScopeValue: BSONCodeWithScope? {
        guard case let .codeWithScope(d) = self else {
            return nil
        }
        return d
    }
}

/// Helper functions for converting to numbers.
extension BSON {
    /// Return this BSON as an `Int` if possible.
    /// This will coerce non-integer numeric cases (e.g. `.double`) into an `Int` if such coercion would be lossless.
    public func toInt() -> Int? {
        switch self {
        case let .int32(value):
            return Int(value)
        case let .int64(value):
            return Int(exactly: value)
        case let .double(value):
            return Int(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as an `Int32` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into an `Int32` if such coercion would be lossless.
    public func toInt32() -> Int32? {
        switch self {
        case let .int32(value):
            return value
        case let .int64(value):
            return Int32(exactly: value)
        case let .double(value):
            return Int32(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as an `Int64` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into an `Int64` if such coercion would be lossless.
    public func toInt64() -> Int64? {
        switch self {
        case let .int32(value):
            return Int64(value)
        case let .int64(value):
            return value
        case let .double(value):
            return Int64(exactly: value)
        default:
            return nil
        }
    }

    /// Return this BSON as a `Double` if possible.
    /// This will coerce numeric cases (e.g. `.int32`) into a `Double` if such coercion would be lossless.
    public func toDouble() -> Double? {
        switch self {
        case let .double(d):
            return d
        default:
            guard let intValue = self.toInt() else {
                return nil
            }
            return Double(intValue)
        }
    }

    /// Return this BSON as a `BSONDecimal128` if possible.
    /// This will coerce numeric cases (e.g. `.double`) into a `BSONDecimal128` if such coercion would be lossless.
    public func toDecimal128() -> BSONDecimal128? {
        switch self {
        case let .decimal128(d):
            return d
        case let .int64(i):
            return try? BSONDecimal128(String(i))
        case let .int32(i):
            return try? BSONDecimal128(String(i))
        case let .double(d):
            return try? BSONDecimal128(String(d))
        default:
            return nil
        }
    }
}

/// Extension providing the internal API of `BSON`
extension BSON {
    /// List of all BSONValue types. Can be used to exhaustively check each one at runtime.
    internal static var allBSONTypes: [BSONType: BSONValue.Type] = [
        .document: BSONDocument.self,
        .int32: Int32.self,
        .int64: Int64.self,
        .decimal128: BSONDecimal128.self,
        .bool: Bool.self,
        .string: String.self,
        .double: Double.self,
        .datetime: Date.self,
        .array: [BSON].self,
        .symbol: BSONSymbol.self,
        .timestamp: BSONTimestamp.self,
        .binary: BSONBinary.self,
        .regex: BSONRegularExpression.self,
        .objectID: BSONObjectID.self,
        .dbPointer: BSONDBPointer.self,
        .code: BSONCode.self,
        .codeWithScope: BSONCodeWithScope.self,
        .null: BSONNull.self,
        .undefined: BSONUndefined.self,
        .minKey: BSONMinKey.self,
        .maxKey: BSONMaxKey.self
    ]

    /// Get the associated `BSONValue` to this `BSON` case.
    internal var bsonValue: BSONValue {
        switch self {
        case let .document(v):
            return v
        case let .int32(v):
            return v
        case let .int64(v):
            return v
        case let .decimal128(v):
            return v
        case let .array(v):
            return v
        case let .bool(v):
            return v
        case let .datetime(v):
            return v
        case let .double(v):
            return v
        case let .string(v):
            return v
        case let .symbol(v):
            return v
        case let .timestamp(v):
            return v
        case let .binary(v):
            return v
        case let .regex(v):
            return v
        case let .dbPointer(v):
            return v
        case let .objectID(v):
            return v
        case let .code(v):
            return v
        case let .codeWithScope(v):
            return v
        case .null:
            return BSONNull()
        case .undefined:
            return BSONUndefined()
        case .minKey:
            return BSONMinKey()
        case .maxKey:
            return BSONMaxKey()
        }
    }
}

extension BSON: ExpressibleByIntegerLiteral {
    /// Initialize a `BSON` from an integer. On 64-bit systems, this will result in an `.int64`. On 32-bit systems,
    /// this will result in an `.int32`.
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension BSON: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension BSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension BSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self = .document(BSONDocument(keyValuePairs: elements))
    }
}

extension BSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension BSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: BSON...) {
        self = .array(elements)
    }
}

extension BSON: Equatable {}
extension BSON: Hashable {}

extension BSON: Codable {
    public init(from decoder: Decoder) throws {
        if let bsonDecoder = decoder as? _BSONDecoder {
            // This path only taken if a BSON is directly decoded at the top-level. Otherwise execution will never reach
            // this point.
            self = try bsonDecoder.decodeBSON()
        } else {
            // This path is taken no matter what when a non-BSONDecoder is used.
            for bsonType in BSON.allBSONTypes.values {
                if let value = try? bsonType.init(from: decoder) {
                    self = value.bson
                }
            }

            throw DecodingError.typeMismatch(
                BSON.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Encountered a value that could not be decoded to any BSON type"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        // This is only reached when a non-BSON encoder is used.
        try self.bsonValue.encode(to: encoder)
    }
}
