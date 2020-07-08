import NIO

/// A struct to represent the deprecated Symbol type.
/// Symbols cannot be instantiated, but they can be read from existing documents that contain them.
public struct BSONSymbol: BSONValue, CustomStringConvertible, Equatable, Hashable {
    internal static var bsonType: BSONType { .symbol }

    internal var bson: BSON { .symbol(self) }

    public var description: String { self.stringValue }

    /// String representation of this `BSONSymbol`.
    public let stringValue: String

    internal init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        let string = try String.read(from: &buffer)
        guard let stringValue = string.stringValue else {
            throw BSONError.InternalError(message: "Cannot get string value of BSON symbol")
        }
        return .symbol(BSONSymbol(stringValue))
    }

    internal func write(to buffer: inout ByteBuffer) {
        self.stringValue.write(to: &buffer)
    }
}
