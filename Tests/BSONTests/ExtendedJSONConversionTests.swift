@testable import BSON
import Foundation
import Nimble
import NIO
import XCTest

open class ExtendedJSONConversionTestCase: BSONTestCase {
    func testAnyExtJSON() throws {
        // Success cases
        expect(try BSON(fromExtJSON: "hello", keyPath: [])).to(equal(BSON.string("hello")))
        let document = try BSON(fromExtJSON: ["num": ["$numberInt": "5"], "extra": 1], keyPath: [])
        expect(document.documentValue!["num"]).to(equal(.int32(5)))
        expect(document.documentValue!["extra"]).to(equal(.int32(1)))
    }

    func testObjectId() throws {
        let oid = "5F07445CFBBBBBBBBBFAAAAA"

        // Success case
        expect(try BSONObjectID(fromExtJSON: ["$oid": JSON.string(oid)], keyPath: [])).to(equal(try BSONObjectID(oid)))

        // Nil cases
        expect(try BSONObjectID(fromExtJSON: ["random": "hello"], keyPath: [])).to(beNil())
        expect(try BSONObjectID(fromExtJSON: "hello", keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONObjectID(fromExtJSON: ["$oid": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONObjectID(fromExtJSON: ["$oid": "hello"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONObjectID(fromExtJSON: ["$oid": .string(oid), "extra": "hello"], keyPath: []))
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
        expect(try Int32(fromExtJSON: .number(Double(Int32.max) + 1), keyPath: [])).to(beNil())
        expect(try Int32(fromExtJSON: .bool(true), keyPath: [])).to(beNil())
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
        expect(try Int64(fromExtJSON: .number(Double(Int64.max) + 1), keyPath: [])).to(beNil())
        expect(try Int64(fromExtJSON: .bool(true), keyPath: [])).to(beNil())
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
        expect(try Double(fromExtJSON: .bool(true), keyPath: [])).to(beNil())
        expect(try Double(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try Double(fromExtJSON: ["$numberDouble": 5.5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Double(fromExtJSON: ["$numberDouble": "5.5", "extra": true], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try Double(fromExtJSON: ["$numberDouble": .bool(true)], keyPath: ["key", "path"]))
            .to(throwError(errorType: DecodingError.self))
    }

    func testDecimal128() throws {
        // Success cases
        expect(try BSONDecimal128(fromExtJSON: ["$numberDecimal": "0.020000000000000004"], keyPath: []))
            .to(equal(try BSONDecimal128("0.020000000000000004")))

        // Nil cases
        expect(try BSONDecimal128(fromExtJSON: .bool(true), keyPath: [])).to(beNil())
        expect(try BSONDecimal128(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONDecimal128(fromExtJSON: ["$numberDecimal": 0.020000000000000004], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDecimal128(fromExtJSON: ["$numberDecimal": "5.5", "extra": true], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDecimal128(fromExtJSON: ["$numberDecimal": .bool(true)], keyPath: ["key", "path"]))
            .to(throwError(errorType: DecodingError.self))
    }

    func testBinary() throws {
        // Success case
        try expect(try BSONBinary(fromExtJSON: ["$binary": ["base64": "//8=", "subType": "00"]], keyPath: []))
            .to(equal(BSONBinary(base64: "//8=", subtype: .generic)))
        try expect(try BSONBinary(fromExtJSON: ["$binary": ["base64": "//8=", "subType": "81"]], keyPath: []))
            .to(equal(BSONBinary(base64: "//8=", subtype: .userDefined(129))))

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
        // Success case
        expect(try BSONCodeWithScope(fromExtJSON: ["$code": "javascript", "$scope": ["doc": "scope"]], keyPath: []))
            .to(equal(BSONCodeWithScope(
                code: "javascript",
                scope: BSONDocument(keyValuePairs: [("doc", BSON.string("scope"))])
            )))

        // Error cases
        expect(try BSONCodeWithScope(fromExtJSON: ["$code": 5, "$scope": ["doc": "scope"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONCodeWithScope(fromExtJSON: ["$code": "javascript", "$scope": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testDocument() throws {
        // Success case
        expect(try BSONDocument(fromExtJSON: ["key": ["$numberInt": "5"]], keyPath: []))
            .to(equal(BSONDocument(keyValuePairs: [("key", .int32(5))])))
        // Nil case
        expect(try BSONDocument(fromExtJSON: 1, keyPath: [])).to(beNil())

        // Error case
        expect { try BSONDocument(fromExtJSON: ["time": ["$timestamp": 5]], keyPath: []) }
            .to(throwError(DecodingError._extendedJSONError(
                keyPath: ["time"],
                debugDescription: "Expected number(5.0) to be an object"
            )))
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
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": "i"]],
            keyPath: []
        )).to(equal(BSONRegularExpression(pattern: "p", options: "i")))
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": ""]],
            keyPath: []
        )).to(equal(BSONRegularExpression(pattern: "p", options: "")))
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": "xi"]],
            keyPath: []
        )).to(equal(BSONRegularExpression(pattern: "p", options: "ix")))
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": "invalid"]],
            keyPath: []
        )).to(equal(BSONRegularExpression(pattern: "p", options: "invalid")))

        // Nil cases
        expect(try BSONRegularExpression(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONRegularExpression(fromExtJSON: ["random": 5], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(fromExtJSON: ["$regularExpression": ["pattern": "p"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": "", "extra": "2"]],
            keyPath: []
        )).to(throwError(errorType: DecodingError.self))
        expect(try BSONRegularExpression(
            fromExtJSON: ["$regularExpression": ["pattern": "p", "options": ""], "extra": "2"],
            keyPath: []
        )).to(throwError(errorType: DecodingError.self))
    }

    func testDBPointer() throws {
        let oid = JSON.object(["$oid": .string("5F07445CFBBBBBBBBBFAAAAA")])
        let objectId: BSONObjectID = try BSONObjectID("5F07445CFBBBBBBBBBFAAAAA")

        // Success case
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace", "$id": oid]], keyPath: []))
            .to(equal(BSONDBPointer(ref: "namespace", id: objectId)))

        // Nil cases
        expect(try BSONDBPointer(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(try BSONDBPointer(fromExtJSON: ["random": 5], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": 5], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace"]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace", "$id": 1]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": true, "$id": oid]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace", "$id": ["$oid": "x"]]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace", "$id": oid, "3": 3]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONDBPointer(fromExtJSON: ["$dbPointer": ["$ref": "namespace", "$id": oid], "x": "2"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testDatetime() throws {
        // Canonical Success case
        expect(try Date(fromExtJSON: ["$date": ["$numberLong": "500004"]], keyPath: []))
            .to(equal(Date(msSinceEpoch: 500_004)))
        // Relaxed Success case
        expect(try Date(fromExtJSON: ["$date": "2012-12-24T12:15:30.501Z"], keyPath: []))
            .to(equal(ExtendedJSONDecoder.extJSONDateFormatter.date(from: "2012-12-24T12:15:30.501Z")))
    }

    func testMinKey() throws {
        // Success cases
        expect(try BSONMinKey(fromExtJSON: ["$minKey": 1], keyPath: [])).to(equal(BSONMinKey()))

        // Nil cases
        expect(try BSONMinKey(fromExtJSON: "minKey", keyPath: [])).to(beNil())
        expect(try BSONMinKey(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONMinKey(fromExtJSON: ["$minKey": 1, "extra": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONMinKey(fromExtJSON: ["$minKey": "random"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testMaxKey() throws {
        // Success cases
        expect(try BSONMaxKey(fromExtJSON: ["$maxKey": 1], keyPath: [])).to(equal(BSONMaxKey()))

        // Nil cases
        expect(try BSONMaxKey(fromExtJSON: "maxKey", keyPath: [])).to(beNil())
        expect(try BSONMaxKey(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONMaxKey(fromExtJSON: ["$maxKey": 1, "extra": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONMaxKey(fromExtJSON: ["$maxKey": "random"], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testUndefined() throws {
        // Success cases
        expect(try BSONUndefined(fromExtJSON: ["$undefined": .bool(true)], keyPath: [])).to(equal(BSONUndefined()))

        // Nil cases
        expect(try BSONUndefined(fromExtJSON: "undefined", keyPath: [])).to(beNil())
        expect(try BSONUndefined(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())

        // Error cases
        expect(try BSONUndefined(fromExtJSON: ["$undefined": .bool(true), "extra": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
        expect(try BSONUndefined(fromExtJSON: ["$undefined": 1], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testArray() throws {
        // Success cases
        expect(try Array(fromExtJSON: [1, ["$numberLong": "2"], "3"], keyPath: []))
            .to(equal([BSON.int32(Int32(1)), BSON.int64(Int64(2)), BSON.string("3")]))
        expect(try Array(fromExtJSON: [["$numberInt": "1"], ["$numberInt": "2"]], keyPath: []))
            .to(equal([BSON.int32(Int32(1)), BSON.int32(Int32(2))]))

        // Nil case
        expect(try Array(fromExtJSON: ["doc": "1"], keyPath: [])).to(beNil())

        // Error case
        expect(try Array(fromExtJSON: [["$numberInt": 1]], keyPath: []))
            .to(throwError(errorType: DecodingError.self))
    }

    func testBoolean() {
        // Success cases
        expect(Bool(fromExtJSON: .bool(true), keyPath: [])).to(equal(true))

        // Nil cases
        expect(Bool(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(Bool(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())
    }

    func testNull() {
        // Success cases
        expect(BSONNull(fromExtJSON: .null, keyPath: [])).to(equal(BSONNull()))

        // Nil cases
        expect(BSONNull(fromExtJSON: 5.5, keyPath: [])).to(beNil())
        expect(BSONNull(fromExtJSON: ["bad": "5.5"], keyPath: [])).to(beNil())
    }
}
