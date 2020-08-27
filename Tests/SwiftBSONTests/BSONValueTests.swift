@testable import SwiftBSON
import Foundation
import Nimble
import XCTest

final class BSONValueTests: BSONTestCase {
    func testInvalidDecimal128() throws {
        expect(try BSONDecimal128("hi")).to(throwError())
        expect(try BSONDecimal128("123.4.5")).to(throwError())
        expect(try BSONDecimal128("10")).toNot(throwError())

        expect(try BSONDecimal128("nan")).toNot(throwError())
        expect(try BSONDecimal128("nana")).to(throwError())
    }

    func testUUIDBytes() throws {
        let twoBytes = Data(base64Encoded: "//8=")!
        let sixteenBytes = Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!

        // UUIDs must have 16 bytes
        expect(try BSONBinary(data: twoBytes, subtype: .uuidDeprecated))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))
        expect(try BSONBinary(data: twoBytes, subtype: .uuid))
            .to(throwError(errorType: BSONError.InvalidArgumentError.self))
        expect(try BSONBinary(data: sixteenBytes, subtype: .uuidDeprecated)).toNot(throwError())
        expect(try BSONBinary(data: sixteenBytes, subtype: .uuid)).toNot(throwError())
    }

    fileprivate func checkTrueAndFalse(val: BSON, alternate: BSON) {
        expect(val).to(equal(val))
        expect(val).toNot(equal(alternate))
    }

    func testBSONEquatable() throws {
        // Int
        self.checkTrueAndFalse(val: 1, alternate: 2)
        // Int32
        self.checkTrueAndFalse(val: .int32(32), alternate: .int32(33))
        // Int64
        self.checkTrueAndFalse(val: .int64(64), alternate: .int64(65))
        // Double
        self.checkTrueAndFalse(val: 1.618, alternate: 2.718)
        // Decimal128
        self.checkTrueAndFalse(
            val: .decimal128(try BSONDecimal128("1.618")),
            alternate: .decimal128(try BSONDecimal128("2.718"))
        )
        // Bool
        self.checkTrueAndFalse(val: true, alternate: false)
        // String
        self.checkTrueAndFalse(val: "some", alternate: "not some")
        // RegularExpression
        self.checkTrueAndFalse(
            val: .regex(BSONRegularExpression(pattern: ".*", options: "")),
            alternate: .regex(BSONRegularExpression(pattern: ".+", options: ""))
        )
        // Timestamp
        self.checkTrueAndFalse(
            val: .timestamp(BSONTimestamp(timestamp: 1, inc: 2)),
            alternate: .timestamp(BSONTimestamp(timestamp: 5, inc: 10))
        )
        // Date
        self.checkTrueAndFalse(
            val: .datetime(Date(timeIntervalSinceReferenceDate: 5000)),
            alternate: .datetime(Date(timeIntervalSinceReferenceDate: 5001))
        )
        // MinKey & MaxKey
        expect(BSON.minKey).to(equal(.minKey))
        expect(BSON.maxKey).to(equal(.maxKey))
        // ObjectId
        self.checkTrueAndFalse(val: .objectID(), alternate: .objectID())
        // CodeWithScope
        self.checkTrueAndFalse(
            val: .codeWithScope(BSONCodeWithScope(code: "console.log('foo');", scope: [:])),
            alternate: .codeWithScope(BSONCodeWithScope(code: "console.log(x);", scope: ["x": 2]))
        )
        // Binary
        self.checkTrueAndFalse(
            val: .binary(try BSONBinary(data: Data(base64Encoded: "c//SZESzTGmQ6OfR38A11A==")!, subtype: .uuid)),
            alternate: .binary(try BSONBinary(data: Data(base64Encoded: "c//88KLnfdfefOfR33ddFA==")!, subtype: .uuid))
        )
        // Document
        self.checkTrueAndFalse(
            val: [
                "foo": 1.414,
                "bar": "swift",
                "nested": ["a": 1, "b": "2"]
            ],
            alternate: [
                "foo": 1.414,
                "bar": "swift",
                "nested": ["a": 1, "b": "different"]
            ]
        )

        // Different types
        expect(BSON.int32(4)).toNot(equal("swift"))

        // Arrays of different sizes should not be equal
        let b0: BSON = [1, 2]
        let b1: BSON = [1, 2, 3]
        expect(b0).toNot(equal(b1))
    }

    struct BSONNumberTestCase {
        let int: Int?
        let double: Double?
        let int32: Int32?
        let int64: Int64?
        let decimal: BSONDecimal128?

        static func compare<T: Equatable>(computed: T?, expected: T?) {
            guard computed != nil else {
                expect(expected).to(beNil())
                return
            }
            expect(computed).to(equal(expected))
        }

        func run() {
            let candidates: [BSON?] = [
                self.int.map { BSON(integerLiteral: $0) },
                self.double.map { .double($0) },
                self.int32.map { .int32($0) },
                self.int64.map { .int64($0) },
                self.decimal.map { .decimal128($0) }
            ]

            candidates.compactMap { $0 }.forEach { l in
                // Skip the Decimal128 conversions until they're implemented
                // TODO: don't skip these (SWIFT-367)
                guard l.decimal128Value == nil else {
                    return
                }

                BSONNumberTestCase.compare(computed: l.toInt(), expected: self.int)
                BSONNumberTestCase.compare(computed: l.toInt32(), expected: self.int32)
                BSONNumberTestCase.compare(computed: l.toInt64(), expected: self.int64)
                BSONNumberTestCase.compare(computed: l.toDouble(), expected: self.double)

                // Skip double for this conversion since it generates a Decimal128(5.0) =/= Decimal128(5)
                if l.doubleValue == nil {
                    BSONNumberTestCase.compare(computed: l.toDecimal128(), expected: self.decimal)
                }
            }
        }
    }

    func testBSONNumber() throws {
        let decimal128 = try BSONDecimal128("5.5")
        let double: BSON = 5.5

        expect(double.toDouble()).to(equal(5.5))
        expect(double.toDecimal128()).to(equal(decimal128))

        let cases = [
            BSONNumberTestCase(int: 5, double: 5.0, int32: Int32(5), int64: Int64(5), decimal: try BSONDecimal128("5")),
            BSONNumberTestCase(
                int: -5,
                double: -5.0,
                int32: Int32(-5),
                int64: Int64(-5),
                decimal: try BSONDecimal128("-5")
            ),
            BSONNumberTestCase(int: 0, double: 0.0, int32: Int32(0), int64: Int64(0), decimal: try BSONDecimal128("0")),
            BSONNumberTestCase(int: nil, double: 1.234, int32: nil, int64: nil, decimal: try BSONDecimal128("1.234")),
            BSONNumberTestCase(
                int: nil,
                double: -31.234,
                int32: nil,
                int64: nil,
                decimal: try BSONDecimal128("-31.234")
            )
        ]

        cases.forEach { $0.run() }
    }
}
