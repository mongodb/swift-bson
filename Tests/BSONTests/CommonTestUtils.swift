@testable import BSON
import Foundation
import Nimble
import XCTest

/// Cleans and normalizes given JSON Data for comparison purposes
public func clean(json: Data?) throws -> JSON {
    let jsonDecoder = JSONDecoder()
    guard let jsonData = json else {
        fatalError("json should be not nil")
    }
    do {
        let jsonEnum = try jsonDecoder.decode(JSON.self, from: jsonData)
        return jsonEnum
    } catch {
        fatalError("json should be decodable to jsonEnum")
    }
}

// Adds a custom "cleanEqual" predicate that compares Data representing JSON with a JSON string for equality
// after normalizing them with the "clean" function
public func cleanEqual(_ expectedValue: String?) -> Predicate<Data> {
    Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue: Data? = try actualExpression.evaluate()
        let expectedValueData = expectedValue?.data(using: .utf8)
        let cleanedActual = try clean(json: actualValue)
        let cleanedExpected = try clean(json: expectedValueData)
        let matches = cleanedActual == cleanedExpected && expectedValueData != nil
        if expectedValueData == nil || actualValue == nil {
            if expectedValueData == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }
        return PredicateResult(
            status: PredicateStatus(bool: matches),
            message: .expectedCustomValueTo("cleanEqual <\(String(describing: cleanedExpected))>", String(describing: cleanedActual))
        )
    }
}

// Adds a custom "cleanEqual" predicate that compares Data representing JSON with a JSON string for equality
// after normalizing them with the "clean" function
public func cleanEqual(data expectedValue: Data?) -> Predicate<Data> {
    Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let canonicalEncoder = ExtendedJSONEncoder()
        canonicalEncoder.mode = .canonical
        let actualValue: Data = try canonicalEncoder.encode(actualExpression.evaluate())
        let expected: Data = try canonicalEncoder.encode(expectedValue)
        let cleanedActual = try clean(json: actualValue)
        let cleanedExpected = try clean(json: expected)
        let matches = cleanedActual == cleanedExpected && expected != nil
        if expected == nil || actualValue == nil {
            if expected == nil && actualValue != nil {
                return PredicateResult(
                        status: .fail,
                        message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }
        return PredicateResult(
                status: PredicateStatus(bool: matches),
                message: .expectedCustomValueTo("cleanEqual <\(String(describing: cleanedExpected))>", String(describing: cleanedActual))
        )
    }
}
