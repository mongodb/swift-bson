import BSON
import Nimble
import XCTest

open class BSONTestCase: XCTestCase {
    /// Helpers, but nothing yet...
}

public extension Document {
    func toByteString() -> String {
        guard let bytes = self.buffer.getBytes(at: 0, length: self.buffer.readableBytes) else {
            return ""
        }
        var string = ""
        for byte in bytes {
            if (33 < byte) && (byte < 126) {
                string += String(UnicodeScalar(byte))
            } else {
                string += "\\x" + String(format: "%02X", byte)
            }
        }
        return string
    }

    func readAllBytes() -> [UInt8] {
        guard let bytes = self.buffer.getBytes(at: 0, length: self.buffer.readableBytes) else {
            return []
        }
        return bytes
    }
}

public extension Array where Element == UInt8 {
    func toByteString() -> String {
        var string = ""
        for byte in self {
            if (33 < byte) && (byte < 126) {
                string += String(UnicodeScalar(byte))
            } else {
                string += "\\x" + String(format: "%02X", byte)
            }
        }
        return string
    }
}
