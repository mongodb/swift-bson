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

    func testModifying() {
        var doc: BSONDocument = ["a": .int32(32), "b": .int64(64), "c": 20]
        doc["a"] = .int32(45) // change
        doc["c"] = .int32(90) // change type
        doc["b"] = nil // delete
        doc["d"] = 3 // append
        let res: BSONDocument = ["a": .int32(45), "c": .int32(90), "d": 3]
        expect(doc.buffer.byteString).to(equal(res.buffer.byteString))
    }

    func testDelete() {
        var doc: BSONDocument = ["a": .int32(32), "b": .int64(64), "c": 20]
        doc["a"] = nil
        doc["z"] = nil // deleting a key that doesn't exist should be a no-op
        expect(["b", "c"]).to(equal(doc.keys))
    }

    func testDefault() {
        let d: BSONDocument = ["hello": 12]
        expect(d["hello", default: 0xBAD1DEA]).to(equal(12))
        expect(d["a", default: 0xBAD1DEA]).to(equal(0xBAD1DEA))
    }
}
