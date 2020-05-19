import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class BSONTestCase: XCTestCase {
    /// Gets the path of the directory containing spec files, depending on whether
    /// we're running from XCode or the command line
    static var specsPath: String {
        // if we can access the "/Tests" directory, assume we're running from command line
        if FileManager.default.fileExists(atPath: "./Tests") {
            return "./Tests/Specs"
        }
        // otherwise we're in Xcode, get the bundle's resource path
        guard let path = Bundle(for: self).resourcePath else {
            XCTFail("Missing resource path")
            return ""
        }
        return path
    }

    struct TestError: Error {
        let message: String
    }

    func fail(_ message: String = "This should not happen") -> Never {
        XCTFail(message)
        fatalError(message)
    }
}

public struct TestError: LocalizedError {
    public let message: String
    public var errorDescription: String { self.message }

    public init(message: String) {
        self.message = message
    }
}

/// Given a spec folder name (e.g. "crud") and optionally a subdirectory name for a folder (e.g. "read") retrieves an
/// array of [(filename, file decoded to type T)].
public func retrieveSpecTestFiles<T: Decodable>(
    specName: String,
    subdirectory: String? = nil,
    asType _: T.Type
) throws -> [(String, T)] {
    var path = "\(BSONTestCase.specsPath)/\(specName)"
    if let sd = subdirectory {
        path += "/\(sd)"
    }
    return try FileManager.default
        .contentsOfDirectory(atPath: path)
        .filter { $0.hasSuffix(".json") }
        .map { filename in
            let url = URL(fileURLWithPath: "\(path)/\(filename)")
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let jsonResult = try JSONDecoder().decode(T.self, from: data)
            return (filename, jsonResult)
        }
}

public extension BSONDocument {
    func toByteString() -> String {
        guard let bytes = self.buffer.getBytes(at: 0, length: self.buffer.readableBytes) else {
            return ""
        }
        return BSONTests.toByteString(bytes)
    }

    func readAllBytes() -> [UInt8] {
        guard let bytes = self.buffer.getBytes(at: 0, length: self.buffer.readableBytes) else {
            return []
        }
        return bytes
    }
}
public func makeByteString(from bytes: [UInt8]) -> String {
    var string = ""
    for byte in bytes {
        if (33 < byte) && (byte < 126) {
            string += String(UnicodeScalar(byte))
        } else {
            string += "\\x" + String(format: "%02X", byte)
        }
    }
    return string + ", \(String(format: "0x%02X", bytes.count))"
}

extension BSONDocument: NMBCollection {}

func toByteString(_ bytes: [UInt8]?) -> String {
    guard let defbytes = bytes else {
        return "none"
    }
    var string = ""
    for byte in defbytes {
        if (33 < byte) && (byte < 126) {
            string += String(UnicodeScalar(byte))
        } else {
            string += "\\x" + String(format: "%02X", byte)
        }
    }
    return string
}

public func toByteString(buffer: ByteBuffer) -> String {
    "ByteBuffer{" +
        "data: \"\(BSONTests.toByteString(buffer.getBytes(at: 0, length: buffer.capacity)))\"" +
        "len: \(buffer.capacity) or \(String(buffer.capacity, radix: 16))}"
}

public extension Array where Element == UInt8 {
    func toByteString() -> String {
        BSONTests.toByteString(self)
    }
}

/// Useful extensions to the Data type for testing purposes
extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }

        self = data
    }

    var hexDescription: String {
        reduce("") { $0 + String(format: "%02x", $1) }
    }
}
