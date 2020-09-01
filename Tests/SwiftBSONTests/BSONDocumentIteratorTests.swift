import Foundation
import Nimble
@testable import SwiftBSON
import XCTest

final class DocumentIteratorTests: BSONTestCase {
    func testFindByteRangeEmpty() {
        let d: BSONDocument = [:]
        let iter = d.makeIterator()
        let range = iter.findByteRange(for: "item")
        expect(range).to(beNil())
    }

    func testFindByteRangeItemsInt32() {
        let d: BSONDocument = ["item0": .int32(32), "item1": .int32(32)]
        let iter = d.makeIterator()
        let maybeRange = iter.findByteRange(for: "item1")

        expect(maybeRange).toNot(beNil())
        let range = maybeRange!

        let slice = d.buffer.getBytes(at: range.startIndex, length: range.endIndex - range.startIndex)
        var bsonBytes: [UInt8] = []
        bsonBytes += [BSONType.int32.rawValue] // type
        bsonBytes += [UInt8]("item1".utf8) // key
        bsonBytes += [0x00] // null byte
        bsonBytes += [0x20, 0x00, 0x00, 0x00] // value of 32 LE
        expect([range.startIndex, range.endIndex - range.startIndex]).to(equal([15, bsonBytes.count]))
        expect(slice).to(equal(bsonBytes))
    }
}
