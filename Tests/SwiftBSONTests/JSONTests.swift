import Foundation
import Nimble
import NIO
@testable import SwiftBSON
import XCTest

open class JSONTestCase: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    func testInteger() throws {
        // Initializing a JSON with an int works, but it will be cast to a double.
        let intJSON: JSON = 12
        let encoded = try encoder.encode([intJSON])
        /* JSONEncoder currently cannot encode non-object/array top level values.
         To get around this, the generated JSON will need to be wrapped in an array
         and unwrapped again at the end as a workaround.
         This workaround can be removed when Swift 5.3 is the minimum supported version by the BSON library. */
        expect(Double(String(data: encoded.dropFirst().dropLast(), encoding: .utf8)!)!)
            .to(beCloseTo(12))

        let decoded = try decoder.decode([JSON].self, from: encoded)[0]
        expect(decoded.doubleValue).to(beCloseTo(intJSON.doubleValue!))
    }

    func testDouble() throws {
        let doubleJSON: JSON = 12.3
        let encoded = try encoder.encode([doubleJSON])
        expect(Double(String(data: encoded.dropFirst().dropLast(), encoding: .utf8)!)!)
            .to(beCloseTo(12.3))

        let decoded = try decoder.decode([JSON].self, from: encoded)[0]
        expect(decoded.doubleValue).to(beCloseTo(doubleJSON.doubleValue!))
    }

    func testString() throws {
        let stringJSON: JSON = "I am a String"
        let encoded = try encoder.encode([stringJSON])
        expect(String(data: encoded.dropFirst().dropLast(), encoding: .utf8))
            .to(equal("\"I am a String\""))
        let decoded = try decoder.decode([JSON].self, from: encoded)[0]
        expect(decoded).to(equal(stringJSON))
    }

    func testBool() throws {
        let boolJSON: JSON = true
        let encoded = try encoder.encode([boolJSON])
        expect(String(data: encoded.dropFirst().dropLast(), encoding: .utf8))
            .to(equal("true"))
        let decoded = try decoder.decode([JSON].self, from: encoded)[0]
        expect(decoded).to(equal(boolJSON))
    }

    func testArray() throws {
        let arrayJSON: JSON = ["I am a string in an array"]
        let encoded = try encoder.encode(arrayJSON)
        let decoded = try decoder.decode(JSON.self, from: encoded)
        expect(String(data: encoded, encoding: .utf8))
            .to(equal("[\"I am a string in an array\"]"))
        expect(decoded).to(equal(arrayJSON))
    }

    func testObject() throws {
        let objectJSON: JSON = ["Key": "Value"]
        let encoded = try encoder.encode(objectJSON)
        let decoded = try decoder.decode(JSON.self, from: encoded)
        expect(String(data: encoded, encoding: .utf8))
            .to(equal("{\"Key\":\"Value\"}"))
        expect(objectJSON.objectValue!["Key"]!.stringValue!).to(equal("Value"))
        expect(decoded).to(equal(objectJSON))
    }
}
