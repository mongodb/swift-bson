import Foundation
import NIO

// A mapping of regex option characters to their equivalent `NSRegularExpression` option.
// note that there is a BSON regexp option 'l' that `NSRegularExpression`
// doesn't support. The flag will be dropped if BSON containing it is parsed,
// and it will be ignored if passed into `optionsFromString`.
private let regexOptsMap: [Character: NSRegularExpression.Options] = [
    "i": .caseInsensitive,
    "m": .anchorsMatchLines,
    "s": .dotMatchesLineSeparators,
    "u": .useUnicodeWordBoundaries,
    "x": .allowCommentsAndWhitespace
]

/// An extension of `NSRegularExpression` to support conversion to and from `BSONRegularExpression`.
extension NSRegularExpression {
    /// Convert a string of options flags into an equivalent `NSRegularExpression.Options`
    internal static func optionsFromString(_ stringOptions: String) -> NSRegularExpression.Options {
        var optsObj: NSRegularExpression.Options = []
        for o in stringOptions {
            if let value = regexOptsMap[o] {
                optsObj.update(with: value)
            }
        }
        return optsObj
    }

    /// Convert this instance's options object into an alphabetically-sorted string of characters
    internal var stringOptions: String {
        var optsString = ""
        for (char, o) in regexOptsMap { if options.contains(o) { optsString += String(char) } }
        return String(optsString.sorted())
    }
}

/// A struct to represent a BSON regular expression.
public struct BSONRegularExpression: Equatable, Hashable {
    /// The pattern for this regular expression.
    public let pattern: String
    /// A string containing options for this regular expression.
    /// - SeeAlso: https://docs.mongodb.com/manual/reference/operator/query/regex/#op
    public let options: String

    /// Initializes a new `BSONRegularExpression` with the provided pattern and options.
    public init(pattern: String, options: String) {
        self.pattern = pattern
        self.options = String(options.sorted())
    }

    /// Initializes a new `BSONRegularExpression` with the pattern and options of the provided `NSRegularExpression`.
    public init(from regex: NSRegularExpression) {
        self.pattern = regex.pattern
        self.options = regex.stringOptions
    }
    
    /// Converts this `BSONRegularExpression` to an `NSRegularExpression`.
    /// Note: `NSRegularExpression` does not support the `l` locale dependence option, so it will be omitted if it was
    /// set on this instance.
    public func toNSRegularExpression() throws -> NSRegularExpression {
        let opts = NSRegularExpression.optionsFromString(self.options)
        return try NSRegularExpression(pattern: self.pattern, options: opts)
    }
}

extension BSONRegularExpression: BSONValue {
    internal static var bsonType: BSONType { .regex }

    internal var bson: BSON { .regex(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        let regex = try buffer.readCString()
        let flags = try buffer.readCString()
        return .regex(BSONRegularExpression(pattern: regex, options: flags))
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeCString(self.pattern)
        buffer.writeCString(self.options)
    }

    public init(from decoder: Decoder) throws {
        throw getDecodingError(type: Self.self, decoder: decoder)
    }

    public func encode(to: Encoder) throws {
        throw bsonEncodingUnsupportedError(value: self, at: to.codingPath)
    }
}
