@testable import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class ExtendedJSONConversionTestCase: BSONTestCase {
    func testInt32() throws {
        // Success cases
        expect(try Int32(fromExtJSON: 5)).to(equal(5))
        expect(try Int32(fromExtJSON: ["$numberInt": "5"])).to(equal(5))

        // Nil cases
        expect(try Int32(fromExtJSON: JSON.number(Double(Int32.max) + 1))).to(beNil())
        expect(try Int32(fromExtJSON: JSON.bool(true))).to(beNil())
        expect(try Int32(fromExtJSON: ["bad": "5"])).to(beNil())

        // Error cases
        expect(try Int32(fromExtJSON: ["$numberInt": "5", "extra": true]))
            .to(throwError(errorType: DecodingError.self))
        expect(try Int32(fromExtJSON: ["$numberInt": .string("\(Double(Int32.max) + 1)")]))
            .to(throwError(errorType: DecodingError.self))
    }

    // TODO: Add equivalent tests for each type that conforms to `BSONValue`
}
