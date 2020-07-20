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
    /*
     * Initializes a `BSONDBPointer` from ExtendedJSON.
     *
     * Parameters:
     *   - `json`: a `JSON` representing the canonical or relaxed form of ExtendedJSON for a `DBPointer`.
     *   - `keyPath`: an array of `String`s containing the enclosing JSON keys of the current json being passed in.
     *              This is used for error messages.
     *
     * Returns:
     *   - `nil` if the provided value is not a `DBPointer`.
     *
     * Throws:
     *   - `DecodingError` if `json` is a partial match or is malformed.
     */
    internal init?(fromExtJSON json: JSON, keyPath: [String]) throws {
        switch json {
        case let .object(obj):
            // canonical and relaxed extended JSON
            guard let value = obj["$dbPointer"] else {
                return nil
            }
            guard obj.count == 1 else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected only \"$dbPointer\" key, found too many keys: \(obj.keys)"
                )
            }
            guard let dbPointerObj = value.objectValue else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \(value) to be an object"
                )
            }
            guard dbPointerObj.count == 2,
                let ref = dbPointerObj["$ref"],
                let id = dbPointerObj["$id"] else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Expected \"$ref\" and \"$id\" keys, " +
                        "found \(dbPointerObj.keys.count) key(s) within \"$dbPointer\": \(dbPointerObj.keys)"
                )
            }
            guard let refStr = ref.stringValue,
                let idStr = id.stringValue else {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: "Could not parse `BSONDBPointer` from \"\(dbPointerObj)\", " +
                        "the value for \"$ref\" must be a string representing a namespace" +
                        " and the value for \"$id\" must be a string representing an `ObjectId`"
                )
            }
            do {
                let oid = try BSONObjectID(idStr)
                self = BSONDBPointer(ref: refStr, id: oid)
            } catch {
                throw DecodingError._extendedJSONError(
                    keyPath: keyPath,
                    debugDescription: error.localizedDescription
                )
            }
        default:
            return nil
        }
    }

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
