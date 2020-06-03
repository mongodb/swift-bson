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
public extension BSON {
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
}

/// Extension providing the internal API of `BSON`
extension BSON {
    /// List of all BSONValue types. Can be used to exhaustively check each one at runtime.
    internal static var allBSONTypes: [BSONType: BSONValue.Type] = [
        .document: BSONDocument.self,
        .int32: Int32.self,
        .int64: Int64.self
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

extension BSON: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BSON)...) {
        self = .document(BSONDocument(keyValuePairs: elements))
    }
}

extension BSON: Equatable {}
extension BSON: Hashable {}
