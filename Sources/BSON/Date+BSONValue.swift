import Foundation
import NIO

extension Date: BSONValue {
    static var bsonType: BSONType { .datetime }

    var bson: BSON { .datetime(self) }

    /// The number of milliseconds after the Unix epoch that this `Date` occurs.
    internal var msSinceEpoch: Int64 { Int64((self.timeIntervalSince1970 * 1000.0).rounded()) }

    /// Initializes a new `Date` representing the instance `msSinceEpoch` milliseconds
    /// since the Unix epoch.
    internal init(msSinceEpoch: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(msSinceEpoch) / 1000.0)
    }

    static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard let ms = buffer.readInteger(endianness: .little, as: Int64.self) else {
            throw BSONError.InternalError(message: "Unable to read UTC datetime (int64)")
        }
        return .datetime(Date(msSinceEpoch: ms))
    }

    func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.msSinceEpoch, endianness: .little, as: Int64.self)
    }
}
