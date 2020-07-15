@testable import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class ExtendedJSONConversionTestCase: BSONTestCase {
    func testObjectId() throws {
        let oid = "5F07445CFBBBBBBBBBFAAAAA"

        // Success case
        expect(try BSONObjectID(fromExtJSON: ["$oid": JSON.string(oid)], keyPath: [])).to(equal(try BSONObjectID(oid)))

        // Nil cases
        expect(try BSONSymbol(fromExtJSON: ["random": "hello"], keyPath: [])).to(beNil())
        expect(try BSONSymbol(fromExtJSON: "hello", keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONObjectID(fromExtJSON: ["$oid": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONObjectID(fromExtJSON: ["$oid": "hello"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONObjectID(fromExtJSON: ["$oid": JSON.string(oid), "extra": "hello"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testSymbol() throws {
        // Success case
        expect(try BSONSymbol(fromExtJSON: ["$symbol": "hello"], keyPath: [])).to(equal(BSONSymbol("hello")))

        // Nil case
        expect(try BSONSymbol(fromExtJSON: "hello", keyPath: [])).to(beNil())
    }

    func testString() {
        // Success case
        expect(String(fromExtJSON: "hello", keyPath: [])).to(equal("hello"))

        // Nil case
        expect(String(fromExtJSON: ["random": "hello"], keyPath: [])).to(beNil())
    }

    func testInt32() throws {
        // Success cases
        expect(try Int32(fromExtJSON: 5, keyPath: [])).to(equal(5))
        expect(try Int32(fromExtJSON: ["$numberInt": "5"], keyPath: [])).to(equal(5))

        // Nil cases
        expect(try Int32(fromExtJSON: JSON.number(Double(Int32.max) + 1), keyPath: [])).to(beNil())
        expect(try Int32(fromExtJSON: JSON.bool(true), keyPath: [])).to(beNil())
        expect(try Int32(fromExtJSON: ["bad": "5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try Int32(fromExtJSON: ["$numberInt": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Int32(fromExtJSON: ["$numberInt": "5", "extra": true], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Int32(fromExtJSON: ["$numberInt": .string("\(Double(Int32.max) + 1)")], keyPath: ["key", "path"]))
            .to(throwError(errorType: DecodingError.self))
    }

    func testInt64() throws {
        // Success cases
        expect(try Int64(fromExtJSON: 5, keyPath: [])).to(equal(5))
        expect(try Int64(fromExtJSON: ["$numberLong": "5"], keyPath: [])).to(equal(5))

        // Nil cases
        expect(try Int64(fromExtJSON: JSON.number(Double(Int64.max) + 1), keyPath: [])).to(beNil())
        expect(try Int64(fromExtJSON: JSON.bool(true), keyPath: [])).to(beNil())
        expect(try Int64(fromExtJSON: ["bad": "5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try Int64(fromExtJSON: ["$numberLong": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Int64(fromExtJSON: ["$numberLong": "5", "extra": true], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Int64(fromExtJSON: ["$numberLong": .string("\(Double(Int64.max) + 1)")], keyPath: ["key", "path"]))
            .to(throwError(errorType: DecodingError.self))
    }

    /// Tests the BSON Double [finite] and Double [non-finite] types.
    func testDouble() throws {
        // Success cases
        expect(try Double(fromExtJSON: 5.5, keyPath: [])).to(equal(5.5))
        expect(try Double(fromExtJSON: ["$numberDouble": "5.5"], keyPath: [])).to(equal(5.5))
        expect(try Double(fromExtJSON: ["$numberDouble": "Infinity"], keyPath: [])).to(equal(Double.infinity))
        expect(try Double(fromExtJSON: ["$numberDouble": "-Infinity"], keyPath: [])).to(equal(-Double.infinity))
        expect(try Double(fromExtJSON: ["$numberDouble": "NaN"], keyPath: [])?.isNaN).to(beTrue())

        // Nil cases
        expect(try Double(fromExtJSON: JSON.bool(true), keyPath: [])).to(beNil())
        expect(try Double(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try Double(fromExtJSON: ["$numberDouble": 5.5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Double(fromExtJSON: ["$numberDouble": "5.5", "extra": true], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Double(fromExtJSON: ["$numberDouble": JSON.bool(true)], keyPath: ["key", "path"]))
            .to(throwError(errorType: DecodingError.self))
    }

    func testDecimal128() throws {}

    func testBinary() throws {
        // Success case
        try expect(try BSONBinary(fromExtJSON: ["$binary": ["base64": "//8=", "subType": "00"]], keyPath: []))
            .to(equal(BSONBinary(base64: "//8=", subtype: .generic)))

        // Nil cases
        expect(try BSONBinary(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONBinary(fromExtJSON: ["random": "hello"], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONBinary(fromExtJSON: ["$binary": "random"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONBinary(fromExtJSON: ["$binary": ["base64": "bad", "subType": "00"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONBinary(fromExtJSON: ["$binary": ["base64": "//8=", "subType": "bad"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONBinary(fromExtJSON: ["$binary": ["random": "1", "and": "2"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONBinary(fromExtJSON: ["$binary": "1", "extra": "2"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testCode() throws {
        // Success case
        expect(try BSONCode(fromExtJSON: ["$code": "javascript"], keyPath: []))
            .to(equal(BSONCode(code: "javascript")))

        // Nil cases
        expect(try BSONCode(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONCode(fromExtJSON: ["random": 5], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONCode(fromExtJSON: ["$code": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testCodeWScope() throws {
        // Skipping until there is a BSON.init(fromExtJSON) because its recursive
    }

    func testDocument() throws {
        // Skipping until there is a BSON.init(fromExtJSON) because its recursive
    }

    func testTimestamp() throws {
        // Success case
        expect(try BSONTimestamp(fromExtJSON: ["$timestamp": ["t": 1, "i": 2]], keyPath: []))
            .to(equal(BSONTimestamp(timestamp: 1, inc: 2)))

        // Nil cases
        expect(try BSONTimestamp(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONTimestamp(fromExtJSON: ["random": 5], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONTimestamp(fromExtJSON: ["$timestamp": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONTimestamp(fromExtJSON: ["$timestamp": ["t": 1]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONTimestamp(fromExtJSON: ["$timestamp": ["t": 1, "i": 2, "3": 3]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONTimestamp(fromExtJSON: ["$timestamp": ["t": 1, "i": 2], "extra": "2"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testRegularExpression() throws {
        // Success case
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern", "i"]], keyPath: []))
                .to(equal(BSONRegularExpression(pattern: "pattern", options: "i")))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern", ""]], keyPath: []))
                .to(equal(BSONRegularExpression(pattern: "pattern", options: "")))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern", "xi"]], keyPath: []))
                .to(equal(BSONRegularExpression(pattern: "pattern", options: "ix")))

        // Nil cases
        expect(try BSONRegularExpression(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONRegularExpression(fromExtJSON: ["random": 5], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": 5], keyPath: []))
                .to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern"]], keyPath: []))
                .to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern", "", "extra"]], keyPath: []))
                .to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern", ""], "extra": "2"], keyPath: []))
                .to(throwError(errorType: DecodingError.self))
    }

    // TODO: Add equivalent tests for each type that conforms to `BSONValue`
}
