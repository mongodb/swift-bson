@testable import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class ExtendedJSONConversionTestCase: XCTestCase {
    func testInt32() throws {
        expect(try Int32(fromExtJSON: ["$numberInt": "5"])).to(equal(5))
        expect(try Int32(fromExtJSON: ["bad": "5"])).to(throwError(errorType: BSONError.InternalError.self))
    }

    // TODO: Add equivalent tests for each type that conforms to `BSONValue`
}
