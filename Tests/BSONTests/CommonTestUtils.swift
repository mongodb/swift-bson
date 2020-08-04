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

/// Adds a custom "cleanEqual" predicate that compares Data representing JSON with a JSON string for equality
/// after normalizing them with the "clean" function
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
            message: .expectedCustomValueTo(
                "cleanEqual <\(String(describing: cleanedExpected))>",
                String(describing: cleanedActual)
            )
        )
    }
}

/// Adds a custom "sortedEqual" predicate that compares two `BSONDocument`s and returns true if they
/// have the same key/value pairs in them
public func sortedEqual(_ expectedValue: BSONDocument?) -> Predicate<BSONDocument> {
    Predicate.define("sortedEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        let actualValue = try actualExpression.evaluate()

        guard let expected = expectedValue, let actual = actualValue else {
            if expectedValue == nil && actualValue != nil {
                return PredicateResult(
                    status: .fail,
                    message: msg.appendedBeNilHint()
                )
            }
            return PredicateResult(status: .fail, message: msg)
        }

        let matches = expected.sortedEquals(actual)
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

extension BSONDocument {
    /// Compares two `BSONDocument`s and returns true if they have the same key/value pairs in them.
    public func sortedEquals(_ other: BSONDocument) -> Bool {
        let keys = self.keys.sorted()
        let otherKeys = other.keys.sorted()

        // first compare keys, because rearrangeDoc will discard any that don't exist in `expected`
        expect(keys).to(equal(otherKeys))

        let rearranged = rearrangeDoc(other, toLookLike: self)
        return self == rearranged
    }
}

/// Given two documents, returns a copy of the input document with all keys that *don't*
/// exist in `standard` removed, and with all matching keys put in the same order they
/// appear in `standard`.
public func rearrangeDoc(_ input: BSONDocument, toLookLike standard: BSONDocument) -> BSONDocument {
    var output = BSONDocument()
    for (k, v) in standard {
        switch (v, input[k]) {
        case let (.document(sDoc), .document(iDoc)?):
            output[k] = .document(rearrangeDoc(iDoc, toLookLike: sDoc))
        case let (.array(sArr), .array(iArr)?):
            var newArr: [BSON] = []
            for (i, el) in iArr.enumerated() {
                if let docEl = el.documentValue, let sDoc = sArr[i].documentValue {
                    newArr.append(.document(rearrangeDoc(docEl, toLookLike: sDoc)))
                } else {
                    newArr.append(el)
                }
            }
            output[k] = .array(newArr)
        default:
            output[k] = input[k]
        }
    }
    return output
}
