import BSON
import Foundation
import Nimble

final class DocumentTests: BSONTestCase {
    // This is a test in itself, will fail to compile on unsupported values
    static let testDoc: BSONDocument = [
        "int": 0xBAD1DEA,
        "int32": .int32(32),
        "int64": .int64(64)
    ]

    func testInt32Encoding() {
        let testDoc: BSONDocument = ["int32": .int32(32)]
        var bsonBytes: [UInt8] = []
        bsonBytes += [BSONType.int32.rawValue] // type
        bsonBytes += Array("int32".utf8) // key
        bsonBytes += [0x00] // null byte
        bsonBytes += [0x20, 0x00, 0x00, 0x00] // value of 32 LE
        bsonBytes += [0x00] // finisher null

        let size = Int32(bsonBytes.count + 4)
        bsonBytes = withUnsafeBytes(of: size.littleEndian, [UInt8].init) + bsonBytes

        expect(testDoc.toByteString()).to(equal(bsonBytes.toByteString()))
    }

    func testInt64Encoding() {
        let testDoc: BSONDocument = ["int64": .int64(64)]
        var bsonBytes: [UInt8] = []
        // bsonBytes += [0x10, 0x00, 0x00, 0x00] // size
        bsonBytes += [BSONType.int64.rawValue] // type
        bsonBytes += Array("int64".utf8) // key
        bsonBytes += [0x00] // null byte
        bsonBytes += [0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] // value of 64 LE
        bsonBytes += [0x00] // finisher null

        let size = Int32(bsonBytes.count + 4)
        bsonBytes = withUnsafeBytes(of: size.littleEndian, [UInt8].init) + bsonBytes

        expect(testDoc.toByteString()).to(equal(bsonBytes.toByteString()))
    }

    func testDecimal128Encoding() {
        let testDoc: BSONDocument = ["dec128": .decimal128(try! Decimal128(fromString: "2.000"))]
        var bsonBytes: [UInt8] = []
        // 18_00_00_00 13 dec128 00 D0070000000000000000000000003A30 00
        bsonBytes += [BSONType.decimal128.toByte] // type
        bsonBytes += Array("dec128".utf8) // key
        bsonBytes += [0x00] // null byte
        // LE Decimal128 2.000
        bsonBytes += [0xD0, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3A, 0x30]
        bsonBytes += [0x00] // finisher null

        let size = Int32(bsonBytes.count + 4)
        bsonBytes = withUnsafeBytes(of: size.littleEndian, [UInt8].init) + bsonBytes

        expect(testDoc.toByteString()).to(equal(bsonBytes.toByteString()))
    }

    func testCount() {
        expect(DocumentTests.testDoc).to(haveCount(3))
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
