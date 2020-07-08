@testable import BSON
import Foundation
import Nimble

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
        let oid = try BSONObjectID("FEEEEEEEFBBBBBBBBBFAAAAA")
        expect(oid.timestamp).to(equal(Date(timeIntervalSince1970: 0xFEEE_EEEE)))
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
        // should be ok to say the timestamps are within the same second but just to be safe, omit seconds
        format.dateFormat = "yyyy-MM-dd HH:mm"

        expect(format.string(from: dateFromID)).to(equal(format.string(from: date)))
    }
}
