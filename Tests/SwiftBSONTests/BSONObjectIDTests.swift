import Foundation
import Nimble
@testable import SwiftBSON

extension BSONObjectID {
    // random value
    internal var randomValue: Int {
        var value = Int()
        _ = withUnsafeMutableBytes(of: &value) { self.oid[4..<9].reversed().copyBytes(to: $0) }
        return value
    }

    // counter
    internal var counter: Int {
        var value = Int()
        _ = withUnsafeMutableBytes(of: &value) { self.oid[9..<12].reversed().copyBytes(to: $0) }
        return value
    }
}

final class BSONObjectIDTests: BSONTestCase {
    func testBSONObjectIDGenerator() {
        let id0 = BSONObjectID()
        let id1 = BSONObjectID()

        // counter should increase by 1
        expect(id0.counter).to(equal(id1.counter - 1))
        // check random number doesn't change
        expect(id0.randomValue).to(equal(id1.randomValue))
    }

    func testBSONObjectIDRoundTrip() throws {
        let hex = "1234567890ABCDEF12345678" // random hex objectID
        let oid = try BSONObjectID(hex)
        expect(hex.uppercased()).to(equal(oid.hex.uppercased()))
    }

    func testBSONObjectIDThrowsForBadHex() throws {
        expect(try BSONObjectID("bad1dea")).to(throwError())
    }

    func testFieldAccessors() throws {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        format.timeZone = TimeZone(secondsFromGMT: 0)
        let timestamp = format.date(from: "2020-07-09 16:22:52")
        // 5F07445 is the hex string for the above date
        let oid = try BSONObjectID("5F07445CFBBBBBBBBBFAAAAA")

        expect(oid.timestamp).to(equal(timestamp))
        expect(oid.randomValue).to(equal(0xFB_BBBB_BBBB))
        expect(oid.counter).to(equal(0xFAAAAA))
    }

    func testCounterRollover() throws {
        BSONObjectID.generator.counter.store(0xFFFFFF)
        let id0 = BSONObjectID()
        let id1 = BSONObjectID()
        expect(id0.counter).to(equal(0xFFFFFF))
        expect(id1.counter).to(equal(0x0))
    }

    func testTimestampCreation() throws {
        let oid = BSONObjectID()
        let dateFromID = oid.timestamp
        let date = Date()
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"

        expect(format.string(from: dateFromID)).to(equal(format.string(from: date)))
    }

    /// Test object for testObjectIdJSONCodable
    private struct TestObject: Codable, Equatable {
        private let _id: BSONObjectID

        init(id: BSONObjectID) {
            self._id = id
        }
    }

    func testObjectIdJSONCodable() throws {
        let id = BSONObjectID()
        let obj = TestObject(id: id)
        let output = try JSONEncoder().encode(obj)
        let outputStr = String(decoding: output, as: UTF8.self)
        expect(outputStr).to(equal("{\"_id\":\"\(id.hex)\"}"))

        let decoded = try JSONDecoder().decode(TestObject.self, from: output)
        expect(decoded).to(equal(obj))

        // expect a decoding error when the hex string is invalid
        let invalidHex = id.hex.dropFirst()
        let invalidJSON = "{\"_id\":\"\(invalidHex)\"}".data(using: .utf8)!
        expect(try JSONDecoder().decode(TestObject.self, from: invalidJSON))
            .to(throwError(errorType: DecodingError.self))
    }
}
