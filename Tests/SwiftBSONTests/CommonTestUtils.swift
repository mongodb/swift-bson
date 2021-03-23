import ExtrasJSON
import Foundation
import Nimble
@testable import SwiftBSON
import XCTest

/// Cleans and normalizes given JSON Data for comparison purposes
public func clean(json: Data) throws -> JSON {
    do {
        return try JSON(JSONParser().parse(bytes: json))
    } catch {
        fatalError("json should be decodable to jsonEnum")
    }
}

/// Adds a custom "cleanEqual" predicate that compares Data representing JSON with a JSON string for equality
/// after normalizing them with the "clean" function
public func cleanEqual(_ expectedValue: String) -> Predicate<Data> {
    Predicate.define("cleanEqual <\(stringify(expectedValue))>") { actualExpression, msg in
        guard let actualValue = try actualExpression.evaluate() else {
            return PredicateResult(
                status: .fail,
                message: msg.appendedBeNilHint()
            )
        }
        guard let expectedValueData = expectedValue.data(using: .utf8) else {
            return PredicateResult(status: .fail, message: msg)
        }
        let cleanedActual = try clean(json: actualValue)
        let cleanedExpected = try clean(json: expectedValueData)

        let matches = cleanedActual == cleanedExpected

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

        let matches = expected.equalsIgnoreKeyOrder(actual)
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
    }
}

public func sortedEqual(_ expectedValue: BSON?) -> Predicate<BSON> {
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

        let matches = expected.equalsIgnoreKeyOrder(actual)
        return PredicateResult(status: PredicateStatus(bool: matches), message: msg)
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

extension JSON {
    internal func toString() -> String {
        var bytes: [UInt8] = []
        self.value.appendBytes(to: &bytes)
        return String(data: Data(bytes), encoding: .utf8)!
    }
}
