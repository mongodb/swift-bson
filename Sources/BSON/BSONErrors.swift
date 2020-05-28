import Foundation

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol BSONError: LocalizedError {}

/// An error thrown when the bson library encounters a internal error not caused by the user.
/// This is usually indicative of a bug in the bson library or system related failure (e.g. memory allocation failure).
public struct BSONInternalError: BSONError {
    internal let message: String

    public var errorDescription: String? { self.message }

    public init(_ message: String) { self.message = message }
}
