import BSON
import Foundation
import Nimble
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
    var path = "\(BSONTestCase.specsPath)/\(specName)/tests"
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

extension Document: NMBCollection {}

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
