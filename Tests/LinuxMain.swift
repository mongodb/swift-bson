@testable import BSONTests
import XCTest

extension BSONCorpusTests {
    static var allTests = [
        ("testBSONCorpus", testBSONCorpus),
    ]
}

extension DocumentTests {
    static var allTests = [
        ("testCount", testCount),
        ("testKeys", testKeys),
        ("testValues", testValues),
        ("testSubscript", testSubscript),
        ("testDynamicMemberLookup", testDynamicMemberLookup),
    ]
}

XCTMain([
    testCase(BSONCorpusTests.allTests),
    testCase(DocumentTests.allTests),
])
