@testable import BSON
import Foundation
import Nimble
import XCTest

final class BSONCorpusTests: BSONTestCase {
    /// Test case that includes 'canonical' forms of BSON and Extended JSON that are deemed equivalent and may provide
    /// additional cases or metadata for additional assertions.
    struct BSONCorpusValidityTest: Decodable {
        enum CodingKeys: String, CodingKey {
            case description, canonicalBSON = "canonical_bson", canonicalExtJSON = "canonical_extjson",
                relaxedExtJSON = "relaxed_extjson", degenerateBSON = "degenerate_bson",
                degenerateExtJSON = "degenerate_extjson", convertedBSON = "converted_bson",
                convertedExtJSON = "converted_extjson", lossy
        }

        /// Human-readable test case label.
        let description: String

        /// an (uppercase) big-endian hex representation of a BSON byte string.
        let canonicalBSON: String

        /// a string containing a Canonical Extended JSON document. Because this is itself embedded as a string inside a
        /// JSON document, characters like quote and backslash are escaped.
        let canonicalExtJSON: String

        /// A string containing a Relaxed Extended JSON document.
        /// Because this is itself embedded as a string inside a JSON document, characters like quote and backslash
        /// are escaped.
        let relaxedExtJSON: String?

        /// An (uppercase) big-endian hex representation of a BSON byte string that is technically parsable, but
        /// not in compliance with the BSON spec.
        let degenerateBSON: String?

        /// A string containing an invalid form of Canonical Extended JSON that is still parsable according to
        /// type-specific rules. (For example, "1e100" instead of "1E+100".)
        let degenerateExtJSON: String?

        /// An (uppercase) big-endian hex representation of a BSON byte string. It may be present for deprecated types.
        /// It represents a possible conversion of the deprecated type to a non-deprecated type, e.g. symbol to string.
        let convertedBSON: String?

        /// A string containing a Canonical Extended JSON document.
        /// Because this is itself embedded as a string inside a JSON document, characters like quote and backslash
        /// are escaped.
        /// It may be present for deprecated types and is the Canonical Extended JSON representation of `convertedBson`.
        let convertedExtJSON: String?

        /// A bool that is present (and true) iff `canonicalBson` can't be represented exactly with extended
        /// JSON (e.g. NaN with a payload).
        let lossy: Bool?
    }

    /// A test case that provides an invalid BSON document or field that should result in an error.
    struct BSONCorpusDecodeErrorTest: Decodable {
        /// Human-readable test case label.
        let description: String

        /// An (uppercase) big-endian hex representation of an invalid BSON string that should fail to decode correctly.
        let bson: String
    }

    /// Test case that is type-specific and represents some input that can not be encoded to the BSON type under test.
    struct BSONCorpusParseErrorTest: Decodable {
        /// Human-readable test case label.
        let description: String

        /// A textual or numeric representation of an input that can't be parsed to a valid value of the given type.
        let string: String
    }

    /// A BSON corpus test file for an individual BSON type.
    struct BSONCorpusTestFile: Decodable {
        enum CodingKeys: String, CodingKey {
            case description, bsonType = "bson_type", valid, parseErrors, decodeErrors, deprecated
        }

        /// Human-readable description of the file.
        let description: String

        /// Hex string of the first byte of a BSON element (e.g. "0x01" for type "double").
        /// This will be the synthetic value "0x00" for "whole document" tests like top.json.
        let bsonType: String

        /// An array of validity test cases.
        let valid: [BSONCorpusValidityTest]?

        /// An array of decode error cases.
        let decodeErrors: [BSONCorpusDecodeErrorTest]?

        /// An array of type-specific parse error cases.
        let parseErrors: [BSONCorpusParseErrorTest]?

        /// This field will be present (and true) if the BSON type being tested has been deprecated (e.g. Symbol)
        let deprecated: Bool?
    }

    // swiftlint:disable:next cyclomatic_complexity
    func testBSONCorpus() throws {
        let SKIPPED_CORPUS_TESTS = [
            "Decimal128":
                [
                    // TODO: SWIFT-962
                    "Exact rounding",
                    "[dqbsr531] negatives (Rounded)",
                    "[dqbsr431] check rounding modes heeded (Rounded)",
                    "OK2",
                    // TODO: SWIFT-965
                    "[decq438] clamped zeros... (Clamped)",
                    "[decq418] clamped zeros... (Clamped)"
                ],
            "Array":
                [
                    // TODO: SWIFT-963
                    "Multi Element Array with duplicate indexes",
                    "Single Element Array with index set incorrectly to empty string",
                    "Single Element Array with index set incorrectly to ab"
                ],
            "Top-level document validity": [
                "Bad DBRef (ref is number, not string)",
                "Bad DBRef (db is number, not string)"
            ]
        ]

        let shouldSkip = { testFileDesc, testDesc in
            SKIPPED_CORPUS_TESTS[testFileDesc]?.contains { $0 == testDesc } == true
        }

        let decoder = ExtendedJSONDecoder()

        for (_, testFile) in try retrieveSpecTestFiles(specName: "bson-corpus", asType: BSONCorpusTestFile.self) {
            if let validityTests = testFile.valid {
                for test in validityTests {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }
                    guard let cBData = Data(hexString: test.canonicalBSON) else {
                        XCTFail("Unable to interpret canonical_bson as Data")
                        return
                    }
                    guard let cEJData = test.canonicalExtJSON.data(using: .utf8) else {
                        XCTFail("Unable to interpret canonical_extjson as Data")
                        return
                    }

                    let lossy = test.lossy ?? false

                    // for cB input:
                    // native_to_bson( bson_to_native(cB) ) = cB
                    let docFromCB = try BSONDocument(fromBSON: cBData)
                    expect(docFromCB.toData()).to(equal(cBData))

                    // test round tripping through documents
                    // We create an array by reading every element out of the document (and therefore out of the
                    // BSONDocument). We then create a new document and append each element of the array to it.
                    // Once that is done, every element in the original document will have gone from
                    // BSONDocument -> Swift data type -> BSONDocument.
                    // At the end, the new BSONDocument should be identical to the original one.
                    // If not, our BSONDocument translation layer is lossy and/or buggy.
                    // TODO(SWIFT-867): Enable these lines when you can do subscript assignment
                    let nativeFromDoc = docFromCB.toArray()
                    let docFromNative = BSONDocument(fromArray: nativeFromDoc)
                    expect(docFromNative.toByteString()).to(equal(cBData.toByteString()))

                    // native_to_canonical_extended_json( bson_to_native(cB) ) = cEJ
                    let canonicalEncoder = ExtendedJSONEncoder()
                    canonicalEncoder.mode = .canonical
                    expect(try canonicalEncoder.encode(docFromCB))
                        .to(cleanEqual(test.canonicalExtJSON), description: test.description)

                    // native_to_relaxed_extended_json( bson_to_native(cB) ) = rEJ (if rEJ exists)
                    let relaxedEncoder = ExtendedJSONEncoder() // default mode is .relaxed
                    if let rEJ = test.relaxedExtJSON {
                        expect(try relaxedEncoder.encode(docFromCB))
                            .to(cleanEqual(rEJ), description: test.description)
                    }

                    // for cEJ input:
                    // native_to_canonical_extended_json( json_to_native(cEJ) ) = cEJ
                    expect(try canonicalEncoder.encode(try decoder.decode(BSONDocument.self, from: cEJData)))
                        .to(cleanEqual(test.canonicalExtJSON), description: test.description)

                    // native_to_bson( json_to_native(cEJ) ) = cB (unless lossy)
                    if !lossy {
                        expect(try decoder.decode(BSONDocument.self, from: cEJData))
                            .to(sortedEqual(docFromCB), description: test.description)
                    }

                    // for dB input (if it exists): (change to language native part)
                    if let dB = test.degenerateBSON {
                        guard let dBData = Data(hexString: dB) else {
                            XCTFail("Unable to interpret degenerate_bson as Data")
                            return
                        }

                        let docFromDB = try BSONDocument(fromBSON: dBData)

                        // SKIPPING: native_to_bson( bson_to_native(dB) ) = cB
                        // We only validate the BSON bytes, we do not clean them up, so can't do this assertion
                        // Degenerate BSON round trip tests will be added in SWIFT-964

                        // native_to_canonical_extended_json( bson_to_native(dB) ) = cEJ
                        // (Not in spec yet, might be added in DRIVERS-1355)
                        expect(try canonicalEncoder.encode(docFromDB))
                            .to(cleanEqual(test.canonicalExtJSON))

                        // native_to_relaxed_extended_json( bson_to_native(dB) ) = rEJ (if rEJ exists)
                        // (Not in spec yet, might be added in DRIVERS-1355)
                        if let rEJ = test.relaxedExtJSON {
                            expect(try relaxedEncoder.encode(docFromDB))
                                .to(cleanEqual(rEJ), description: test.description)
                        }
                    }

                    // for dEJ input (if it exists):
                    if let dEJ = test.degenerateExtJSON, let dEJData = dEJ.data(using: .utf8) {
                        // native_to_canonical_extended_json( json_to_native(dEJ) ) = cEJ
                        expect(try canonicalEncoder.encode(try decoder.decode(BSONDocument.self, from: dEJData)))
                            .to(cleanEqual(test.canonicalExtJSON), description: test.description)
                        // native_to_bson( json_to_native(dEJ) ) = cB (unless lossy)
                        if !lossy {
                            try expect(try decoder.decode(BSONDocument.self, from: dEJData))
                                .to(sortedEqual(BSONDocument(fromBSON: cBData)), description: test.description)
                        }
                    }

                    // for rEJ input (if it exists):
                    if let rEJ = test.relaxedExtJSON, let rEJData = rEJ.data(using: .utf8) {
                        // native_to_relaxed_extended_json( json_to_native(rEJ) ) = rEJ
                        expect(try relaxedEncoder.encode(try decoder.decode(BSONDocument.self, from: rEJData)))
                            .to(cleanEqual(rEJ), description: test.description)
                    }
                }
            }

            if let parseErrorTests = testFile.parseErrors {
                for test in parseErrorTests {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }
                    let description = "\(testFile.description)-\(test.description)"
                    switch BSONType(rawValue: UInt8(testFile.bsonType.dropFirst(2), radix: 16)!)! {
                    case .invalid: // "top level document" uses 0x00 for the bson type
                        guard let testData = test.string.data(using: .utf8) else {
                            XCTFail("Unable to interpret canonical_bson as Data")
                            return
                        }
                        expect(try decoder.decode(BSONDocument.self, from: testData))
                            .to(throwError(errorType: DecodingError.self), description: description)
                    case .decimal128:
                        continue // TODO: SWIFT-968
                    default:
                        throw TestError(
                            message: "\(description): parse error tests not implemented"
                                + "for bson type \(testFile.bsonType)"
                        )
                    }
                }
            }

            if let decodeErrors = testFile.decodeErrors {
                for test in decodeErrors {
                    guard !shouldSkip(testFile.description, test.description) else {
                        continue
                    }
                    let description = "\(testFile.description)-\(test.description)"
                    guard let data = Data(hexString: test.bson) else {
                        XCTFail("\(description): Unable to interpret bson as Data")
                        return
                    }
                    expect(try BSONDocument(fromBSON: data)).to(throwError(), description: description)
                }
            }
        }
    }
}
