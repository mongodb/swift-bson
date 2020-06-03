@testable import BSONTests
@testable import MongoSwiftSyncTests
@testable import MongoSwiftTests
import XCTest

extension BSONCorpusTests {
    static var allTests = [
        ("testBSONCorpus", testBSONCorpus)
    ]
}

extension DocumentIteratorTests {
    static var allTests = [
        ("testFindByteRangeEmpty", testFindByteRangeEmpty),
        ("testFindByteRangeItemsInt32", testFindByteRangeItemsInt32)
    ]
}

extension DocumentTests {
    static var allTests = [
        ("testInt32Encoding", testInt32Encoding),
        ("testInt64Encoding", testInt64Encoding),
        ("testDecimal128Encoding", testDecimal128Encoding),
        ("testBoolEncoding", testBoolEncoding),
        ("testSubDocumentEncoding", testSubDocumentEncoding),
        ("testCount", testCount),
        ("testKeys", testKeys),
        ("testValues", testValues),
        ("testSubscript", testSubscript),
        ("testDynamicMemberLookup", testDynamicMemberLookup)
    ]
}

XCTMain([
    testCase(BSONCorpusTests.allTests),
    testCase(DocumentIteratorTests.allTests),
    testCase(DocumentTests.allTests)
])
