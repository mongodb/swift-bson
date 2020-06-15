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

    /// Initialize a `BSON` from an integer. On 64-bit systems, this will result in an `.int64`. On 32-bit systems,
    /// this will result in an `.int32`.
    public init(_ int: Int) {
        if MemoryLayout<Int>.size == 4 {
            self = .int32(Int32(int))
        } else {
            self = .int64(Int64(int))
        }
    }

    /// Get the `BSONType` of this `BSON`.
    public var type: BSONType {
        self.bsonValue.bsonType
    }
}

/// Value getters
extension BSON {
    /// If this `BSON` is an `.int32`, return it as an `Int32`. Otherwise, return nil.
    var int32Value: Int32? {
        guard case let .int32(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is an `.int64`, return it as an `Int64`. Otherwise, return nil.
    var int64Value: Int64? {
        guard case let .int64(i) = self else {
            return nil
        }
        return i
    }

    /// If this `BSON` is a `.document`, return it as a `BSONDocument`. Otherwise, return nil.
    var documentValue: BSONDocument? {
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
}

/// Extension providing the internal API of `BSON`
extension BSON {
    /// List of all BSONValue types. Can be used to exhaustively check each one at runtime.
    internal static var allBSONTypes: [BSONType: BSONValue.Type] = [
        .document: BSONDocument.self,
        .int32: Int32.self,
        .int64: Int64.self,
        .bool: Bool.self,
        .string: String.self,
        .double: Double.self,
        .datetime: Date.self,
        .array: [BSON].self,
        .symbol: BSONSymbol.self,
        .timestamp: BSONTimestamp.self,
        .binary: BSONBinary.self,
        .regex: BSONRegularExpression.self
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
