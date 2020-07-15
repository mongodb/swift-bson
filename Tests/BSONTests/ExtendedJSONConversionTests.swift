@testable import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class ExtendedJSONConversionTestCase: XCTestCase {
    func testInt32() throws {
        // Success cases
        expect(try Int32(fromExtJSON: 5)).to(equal(5))
        expect(try Int32(fromExtJSON: ["$numberInt": "5"])).to(equal(5))

        // Nil cases
        expect(try Int32(fromExtJSON: JSON.number(Double(Int32.max) + 1))).to(beNil())
        expect(try Int32(fromExtJSON: JSON.bool(true))).to(beNil())

        // Error cases
        expect(try Int32(fromExtJSON: ["$numberInt": "5", "extra": true]))
            .to(throwError(errorType: BSONError.InternalError.self))
        expect(try Int32(fromExtJSON: ["$numberInt": .number(Double(Int32.max) + 1)]))
            .to(throwError(errorType: BSONError.InternalError.self))
        expect(try Int32(fromExtJSON: ["bad": "5"]))
            .to(throwError(errorType: BSONError.InternalError.self))
    }

    // TODO: Add equivalent tests for each type that conforms to `BSONValue`
}
