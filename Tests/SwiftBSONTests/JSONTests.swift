import ExtrasJSON
import Foundation
import Nimble
import NIO
@testable import SwiftBSON
import XCTest

open class JSONTestCase: XCTestCase {
    let encoder = XJSONEncoder()
    let decoder = XJSONDecoder()

    func testInteger() throws {
        // Initializing a JSON with an int works, but it will be cast to a double.
        let intJSON: JSON = 12
        let encoded = Data(try encoder.encode([intJSON]))
        /* JSONEncoder currently cannot encode non-object/array top level values.
         To get around this, the generated JSON will need to be wrapped in an array
         and unwrapped again at the end as a workaround.
         This workaround can be removed when Swift 5.3 is the minimum supported version by the BSON library. */
        expect(Double(String(data: encoded.dropFirst().dropLast(), encoding: .utf8)!)!)
            .to(beCloseTo(12))
    }

    func testDouble() throws {
        let doubleJSON: JSON = 12.3
        let encoded = Data(try encoder.encode([doubleJSON]))
        expect(Double(String(data: encoded.dropFirst().dropLast(), encoding: .utf8)!)!)
            .to(beCloseTo(12.3))
    }

    func testString() throws {
        let stringJSON: JSON = "I am a String"
        let encoded = Data(try encoder.encode([stringJSON]))
        expect(String(data: encoded.dropFirst().dropLast(), encoding: .utf8))
            .to(equal("\"I am a String\""))
    }

    func testBool() throws {
        let boolJSON: JSON = true
        let encoded = Data(try encoder.encode([boolJSON]))
        expect(String(data: encoded.dropFirst().dropLast(), encoding: .utf8))
            .to(equal("true"))
    }

    func testArray() throws {
        let arrayJSON: JSON = ["I am a string in an array"]
        let encoded = Data(try encoder.encode(arrayJSON))
        expect(String(data: encoded, encoding: .utf8))
            .to(equal("[\"I am a string in an array\"]"))
    }

    func testObject() throws {
        let objectJSON: JSON = ["Key": "Value"]
        let encoded = Data(try encoder.encode(objectJSON))
        expect(String(data: encoded, encoding: .utf8))
            .to(equal("{\"Key\":\"Value\"}"))
        expect(objectJSON.value.objectValue!["Key"]!.stringValue!).to(equal("Value"))
    }
}
