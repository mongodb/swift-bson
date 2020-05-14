import Foundation

/// An empty protocol for encapsulating all errors that this package can throw.
public protocol BSONError: LocalizedError {}

public struct InternalError: BSONError {
    internal let message: String

    public var errorDescription: String? { self.message }
}
