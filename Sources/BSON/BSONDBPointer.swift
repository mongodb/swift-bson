import NIO

/// A struct to represent the deprecated DBPointer type.
/// DBPointers cannot be instantiated, but they can be read from existing documents that contain them.
public struct BSONDBPointer: Equatable, Hashable {
    /// Destination namespace of the pointer.
    public let ref: String

    /// Destination _id (assumed to be an `BSONObjectID`) of the pointed-to document.
    public let id: BSONObjectID

    internal init(ref: String, id: BSONObjectID) {
        self.ref = ref
        self.id = id
    }
}

extension BSONDBPointer: BSONValue {
    internal static var bsonType: BSONType { .dbPointer }

    internal var bson: BSON { .dbPointer(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let ref = try String.read(from: &buffer).stringValue else {
            throw BSONError.InternalError(message: "Cannot read namespace of DBPointer")
        }
        guard let oid = try BSONObjectID.read(from: &buffer).objectIDValue else {
            throw BSONError.InternalError(message: "Cannot read ObjectID of DBPointer")
        }
        return .dbPointer(BSONDBPointer(ref: ref, id: oid))
    }

    internal func write(to buffer: inout ByteBuffer) {
        self.ref.write(to: &buffer)
        self.id.write(to: &buffer)
    }
}
