import NIO

/// A struct to represent the BSON Code type.
public struct BSONCode: Equatable, Hashable {
    /// A string containing Javascript code.
    public let code: String

    /// Initializes a `BSONCode` with an optional scope value.
    public init(code: String) {
        self.code = code
    }
}

/// A struct to represent BSON CodeWithScope.
public struct BSONCodeWithScope: Equatable, Hashable {
    /// A string containing Javascript code.
    public let code: String

    /// An optional scope `BSONDocument` containing a mapping of identifiers to values,
    /// representing the context in which `code` should be evaluated.
    public let scope: BSONDocument

    /// Initializes a `BSONCodeWithScope` with an optional scope value.
    public init(code: String, scope: BSONDocument) {
        self.code = code
        self.scope = scope
    }
}

extension BSONCode: BSONValue {
    internal static var bsonType: BSONType { .code }

    internal var bson: BSON { .code(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let code = try String.read(from: &buffer).stringValue else {
            throw BSONError.InternalError(message: "Cannot code")
        }
        return .code(BSONCode(code: code))
    }

    internal func write(to buffer: inout ByteBuffer) {
        self.code.write(to: &buffer)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}

extension BSONCodeWithScope: BSONValue {
    internal static var bsonType: BSONType { .codeWithScope }

    internal var bson: BSON { .codeWithScope(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        let reader = buffer.readerIndex
        guard let size = buffer.readInteger(endianness: .little, as: Int32.self) else {
            throw BSONError.InternalError(message: "Cannot code with scope size")
        }
        // 14 bytes minimum size =
        //     min 4 bytes size of CodeWScope
        //     min 4 bytes size of string + 1 null byte req by string
        //     min 5 bytes for document
        guard size >= 14 else {
            throw BSONError.InternalError(message: "Code with scope has size: \(size) but the minimum size is 14")
        }
        guard (size - 4) < buffer.readableBytes else {
            throw BSONError.InternalError(message: "Code with scope has size: \(size) but there "
                + "are only \(buffer.readableBytes) bytes to read")
        }
        guard let code = try String.read(from: &buffer).stringValue else {
            throw BSONError.InternalError(message: "Cannot read code")
        }
        guard let scope = try BSONDocument.read(from: &buffer).documentValue else {
            throw BSONError.InternalError(message: "Cannot read scope document")
        }
        guard (buffer.readerIndex - reader) == size else {
            throw BSONError.InternalError(
                message: "Stated size: \(size) is not correct, actual size: \(buffer.readerIndex - reader)"
            )
        }
        return .codeWithScope(BSONCodeWithScope(code: code, scope: scope))
    }

    internal func write(to buffer: inout ByteBuffer) {
        let writer = buffer.writerIndex
        buffer.writeInteger(0, endianness: .little, as: Int32.self) // reserve space
        self.code.write(to: &buffer)
        self.scope.write(to: &buffer)
        buffer.setInteger(Int32(buffer.writerIndex - writer), at: writer, endianness: .little, as: Int32.self)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}
