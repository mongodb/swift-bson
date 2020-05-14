import BSON
import Foundation
import Nimble

final class DocumentTests: BSONTestCase {
    // This is a test in itself, will fail to compile on unsupported values
    static let testDoc: Document = [
        "int": 0xBAD1DEA,
        "int32": .int32(32),
        "int64": .int64(64)
    ]

    func testInt32Encoding() {
        let testDoc: Document = ["int32": .int32(32)]
        var bsonBytes: [UInt8] = []
        bsonBytes += [0x0C, 0x00, 0x00, 0x00] // size
        bsonBytes += [BSONType.int32.toByte] // type
        bsonBytes += Array("int32".utf8) // key
        bsonBytes += [0x00] // null byte
        bsonBytes += [0x20, 0x00, 0x00, 0x00] // value of 32 LE
        bsonBytes += [0x00] // finisher null
        expect(testDoc.toByteString()).to(equal(bsonBytes.toByteString()))
    }

    func testInt64Encoding() {
        let testDoc: Document = ["int64": .int64(64)]
        var bsonBytes: [UInt8] = []
        bsonBytes += [0x10, 0x00, 0x00, 0x00] // size
        bsonBytes += [BSONType.int64.toByte] // type
        bsonBytes += Array("int64".utf8) // key
        bsonBytes += [0x00] // null byte
        bsonBytes += [0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] // value of 64 LE
        bsonBytes += [0x00] // finisher null
        expect(testDoc.toByteString()).to(equal(bsonBytes.toByteString()))
    }

    func testCount() {
        expect(DocumentTests.testDoc.count).to(equal(3))
    }

    func testKeys() {
        expect(DocumentTests.testDoc.keys).to(equal(["int", "int32", "int64"]))
    }

    func testValues() {
        expect(DocumentTests.testDoc.values[0]).to(equal(0xBAD1DEA))
        expect(DocumentTests.testDoc.values[1]).to(equal(.int32(32)))
        expect(DocumentTests.testDoc.values[2]).to(equal(.int64(64)))
    }

    func testSubscript() {
        expect(DocumentTests.testDoc["int"]).to(equal(0xBAD1DEA))
    }

    func testDynamicMemberLookup() {
        expect(DocumentTests.testDoc.int).to(equal(0xBAD1DEA))
    }
}
