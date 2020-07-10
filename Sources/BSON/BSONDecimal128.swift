import Foundation
import NIO

private extension UInt64 {
    var upper32bits: Self { self.getBits(0...31) }
    var lower32bits: Self { self.getBits(32...63) }

    /// Gets this number's bits without shifting the value down to the LSB
    /// the bits are indexed from MSB at 0 to LSB at 63
    /// example: (0b11010).getBitsUnshifted(0..<4) == 0b110_00
    /// (note: the bits before the _ are the one's gotten)
    func getBitsUnshifted(_ range: ClosedRange<Int>) -> Self {
        guard range.lowerBound >= 0 else {
            return 0
        }
        guard range.upperBound <= 63 else {
            return 0
        }
        var value = UInt64()
        for i in range {
            value |= (self & (0b1 << (63 - i)))
        }
        return value
    }

    /// Gets this number's bits shifting the value down to the LSB
    /// the bits are indexed from MSB at 0 to LSB at 63
    /// example: (0b11010).getBitsUnshifted(0..<4) == 0b110
    func getBits(_ range: ClosedRange<Int>) -> Self {
        var value = self.getBitsUnshifted(range)
        value >>= (63 - range.upperBound)
        return value
    }

    func getBit(_ index: Int) -> Self {
        let shiftAmount = 63 - index
        let value = (self >> shiftAmount) & 0b1
        return value
    }
}

private extension Array where Element == UInt8 {
    func decimalDigitsToUInt64() -> UInt64 {
        var value = UInt64()
        guard !self.isEmpty else {
            return value
        }
        value = UInt64(self[0])
        for digit in self[1...] {
            value *= 10
            value += UInt64(digit)
        }
        return value
    }
}

internal struct UInt128: Equatable, Hashable {
    /// The high order 64 bits
    internal var hi: UInt64
    /// The low order 64 bits
    internal var lo: UInt64

    internal init(hi: UInt64, lo: UInt64) {
        self.hi = hi
        self.lo = lo
    }

    internal init() {
        self.hi = 0
        self.lo = 0
    }

    internal static func multiply(_ left: UInt64, by right: UInt64) -> UInt128 {
        let (product, didOverflow) = left.multipliedReportingOverflow(by: right)
        guard didOverflow else {
            return UInt128(hi: 0, lo: product)
        }

        let leftHi = left.upper32bits
        let leftLo = left.lower32bits

        let rightHi = right.upper32bits
        let rightLo = right.lower32bits

        var productHi = leftHi * rightHi
        let productMid0 = leftHi * rightLo
        let productMid1 = leftLo * rightHi
        var productLo = leftLo * rightLo

        productHi += productMid0.upper32bits
        let productPartial = productMid0.lower32bits + productMid1 + productLo.upper32bits

        productHi += productPartial.upper32bits
        productLo = (productPartial << 32) + productLo.lower32bits

        return UInt128(hi: productHi, lo: productLo)
    }

    internal static func divideBy1Billion(_ numerator: UInt128) -> (quotient: UInt128, remainder: Int) {
        // swiftlint:disable:previous cyclomatic_complexity
        let denominator: UInt64 = 1000 * 1000 * 1000
        var remainder: UInt64 = 0
        var quotient = numerator

        guard !(quotient.hi == 0 && quotient.lo == 0) else {
            return (quotient: quotient, remainder: 0)
        }

        for i in 0...3 {
            // Adjust remainder to match value of next dividend
            remainder <<= 32
            // Add the divided to remainder
            var quotient_i: UInt64
            switch i {
            case 0: quotient_i = quotient.hi.upper32bits
            case 1: quotient_i = quotient.hi.lower32bits
            case 2: quotient_i = quotient.lo.upper32bits
            case 3: quotient_i = quotient.lo.lower32bits
            default: quotient_i = 0
            }
            remainder += quotient_i
            // quotient[i] = Int(remainder / DIVISOR)
            switch i {
            case 0: quotient.hi = (((remainder / denominator) << 32) | quotient.hi.lower32bits)
            case 1: quotient.hi = ((remainder / denominator).lower32bits | quotient.hi.getBitsUnshifted(0...31))
            case 2: quotient.lo = (((remainder / denominator) << 32) | quotient.lo.lower32bits)
            case 3: quotient.lo = ((remainder / denominator).lower32bits | quotient.lo.getBitsUnshifted(0...31))
            default: _ = ()
            }
            // Store the remainder
            remainder %= denominator
        }

        return (quotient: quotient, remainder: Int(remainder.lower32bits))
    }
}

public struct BSONDecimal128: Equatable, Hashable, CustomStringConvertible {
    // swiftlint:disable line_length
    private static let digitsRegex = #"(?:\d+)"#
    private static let indicatorRegex = #"(?:e|E)"#
    private static let signRegex = #"[+-]"#
    private static let infinityRegex = #"Infinity|Inf|infinity|inf"#
    private static let decimalRegex = "\(digitsRegex)\\.\(digitsRegex)?|\\.?\(digitsRegex)"
    private static let nanRegex = #"NaN"#
    private static let exponentRegex = "\(indicatorRegex)(\(signRegex))(\(digitsRegex))"
    private static let numericValueRegex = "(\(signRegex))?(?:(\(decimalRegex))(?:\(exponentRegex))?|(\(infinityRegex)))"
    public static let decimal128Regex = "\(numericValueRegex)|(\(nanRegex))"
    // swiftlint:enable line_length

    // The precision of the Decimal128 format
    private static let maxSignificandDigits = 34
    // NOTE: the min and max values are adjusted for when the decimal point is rounded out
    // e.g, 1.000...*10^-6143 == 1000...*10^-6176
    // In the spec exp_max is 6144 so we use 6111
    private static let exponentMax = 6111
    // In the spec exp_min is -6134 so we use -6176
    private static let exponentMin = -6176
    // The sum of the exponent and a constant (bias) chosen to make the biased exponent’s range non-negative.
    private static let exponentBias = 6176

    private static let decimalShift17Zeroes: UInt64 = 100_000_000_000_000_000
    private static let exponentMask = 0x3FFF

    private static let negativeInfinity = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
    private static let infinity = UInt128(hi: 0x7800_0000_0000_0000, lo: 0)
    private static let NaN = UInt128(hi: 0x7C00_0000_0000_0000, lo: 0)

    private enum REGroups: Int, CaseIterable {
        case sign = 1
        case decimalPart = 2
        case exponentSign = 3
        case exponentPart = 4
        case infinity = 5
        case nan = 6
    }

    public var description: String { self.toString() }

    /// Holder for raw decimal128 value
    private var value: UInt128

    /// Indicators in the combination field that determine number type
    private static let combinationNaN = 0b11111
    private static let combinationInfinity = 0b11110

    /// Determines if the value is Not a Number by checking if bits 1-6 are equal to 1 ignoring sign bit
    private var isNaN: Bool { self.value.hi.getBits(1...5) == Self.combinationNaN }
    /// Determines if the value is Infinity  by checking if bits 1-5 are equal to 1 and bit 6 is 0 ignoring sign bit
    private var isInfinity: Bool { self.value.hi.getBits(1...5) == Self.combinationInfinity }
    /// Determines if the value is Negative
    private var isNegative: Bool { self.value.hi.getBit(0) == 1 }

    internal init(fromUInt128 value: UInt128) {
        self.value = value
    }

    public init(_ data: String) throws {
        // swiftlint:disable:previous cyclomatic_complexity
        let regex = try NSRegularExpression(
            pattern: Self.decimal128Regex,
            options: NSRegularExpression.Options.caseInsensitive
        )
        let wholeRepr = NSRange(data.startIndex..<data.endIndex, in: data)
        guard let match: NSTextCheckingResult = regex.firstMatch(in: data, range: wholeRepr) else {
            throw BSONError.InvalidArgumentError(message: "Syntax Error: \(data) does not match \(regex)")
        }

        var sign = 1
        let signRange: NSRange = match.range(at: REGroups.sign.rawValue)
        if signRange.location != NSNotFound, let range = Range(signRange, in: data) {
            sign = String(data[range]) == "-" ? -1 : 1
        }

        let isNaN = match.range(at: REGroups.nan.rawValue)
        if isNaN.location != NSNotFound {
            self.value = Self.NaN
            return
        }

        let isInfinity = match.range(at: REGroups.infinity.rawValue)
        if isInfinity.location != NSNotFound {
            if sign < 0 {
                self.value = Self.negativeInfinity
                return
            }
            self.value = Self.infinity
            return
        }

        var exponentSign = 1
        let exponentSignRange = match.range(at: REGroups.exponentSign.rawValue)
        if exponentSignRange.location != NSNotFound, let range = Range(exponentSignRange, in: data) {
            exponentSign = String(data[range]) == "-" ? -1 : 1
        }

        let decimalPartNSRange = match.range(at: REGroups.decimalPart.rawValue)
        guard decimalPartNSRange.location != NSNotFound,
            let decimalPartRange = Range(decimalPartNSRange, in: data) else {
            throw BSONError.InvalidArgumentError(message: "Syntax Error: Missing digits in front of the exponent")
        }
        let decimalPart = String(data[decimalPartRange])
        var digits = try Self.convertToDigitsArray(decimalPart)

        var exponent = 0
        let exponentPartRange = match.range(at: REGroups.exponentPart.rawValue)
        if exponentPartRange.location != NSNotFound, let range = Range(exponentPartRange, in: data) {
            exponent = exponentSign * (Int(data[range]) ?? 0)
        }
        if let pointIndex = decimalPart.firstIndex(of: ".") {
            // move the exponent by the number of digits after the decimal point
            // so we are looking at an "integer" significand, easier to reason about
            exponent -= decimalPart.distance(from: pointIndex, to: decimalPart.endIndex) - 1
        }

        while exponent > Self.exponentMax && digits.count <= Self.maxSignificandDigits {
            // Exponent is too large, try shifting zeros into the coefficient
            digits.append(0)
            exponent -= 1
        }

        while exponent < Self.exponentMin && !digits.isEmpty {
            // Exponent is too small, try taking zeros off the coefficient
            if digits.count == 1 && digits[0] == 0 {
                exponent = Self.exponentMin
                break
            }

            if digits.last == 0 {
                digits.removeLast()
                exponent += 1
                continue
            }

            if digits.last != 0 {
                // We don't end in a zero and our exponent is too small
                throw BSONError.InvalidArgumentError(message: "Underflow Error: Value too small")
            }
        }

        guard (Self.exponentMin...Self.exponentMax).contains(exponent) else {
            throw BSONError.InvalidArgumentError(message: "Rounding Error: Cannot round exponent \(exponent) further")
        }

        guard digits.count <= Self.maxSignificandDigits else {
            throw BSONError.InvalidArgumentError(
                message: "Overflow Error: Value cannot exceed \(Self.maxSignificandDigits) digits"
            )
        }

        let significandLoDigits = [UInt8](digits.suffix(Self.maxSignificandDigits / 2)).decimalDigitsToUInt64()
        let significandHiDigits = [UInt8](digits.dropLast(Self.maxSignificandDigits / 2)).decimalDigitsToUInt64()

        // Multiply by one hundred quadrillion (note the seventeen zeroes)
        // the product is the significandHiDigits "shifted" up by 17 decimal places
        // we can then add the significandLoDigits to the product to ensure that we have a correctly formed significand
        var product = UInt128.multiply(significandHiDigits, by: Self.decimalShift17Zeroes)
        product.lo += significandLoDigits

        if product.lo < significandLoDigits {
            // carry over addition to hi side
            product.hi += 1
        }

        let biasedExponent = exponent + Self.exponentBias

        self.value = UInt128()

        // The most significant bit of the significand determines the format
        // Encode combination, exponent, and significand.
        if product.hi.getBit(14) == 1 {
            // The significand has the implicit (0b100) at the
            // beginning of the trailing significand field

            // Ensure we encode '0b11' into bits 1 to 3
            self.value.hi |= (0b11 << 61)
            self.value.hi |= UInt64(biasedExponent & Self.exponentMask) << 47
            self.value.hi |= product.hi.getBits(5...63)
        } else {
            // The significand has the implicit (0b0) at the
            // beginning of the trailing significand field
            self.value.hi |= UInt64(biasedExponent & Self.exponentMask) << 49
            self.value.hi |= product.hi.getBits(3...63)
        }

        self.value.lo = product.lo

        if sign < 0 {
            self.value.hi |= 0x8000_0000_0000_0000
        }
    }

    // swiftlint:disable force_unwrapping
    private static let asciiZero = Character("0").asciiValue!
    private static let asciiNine = Character("9").asciiValue!
    private static let asciiPoint = Character(".").asciiValue!
    // swiftlint:enable force_unwrapping

    /// Take a string of digits (with or without a point) discard leading zeroes
    /// and return the string's digits as an array of integers
    private static func convertToDigitsArray(_ decimalString: String) throws -> [UInt8] {
        var leadingZero = true
        var digits: [UInt8] = []

        let digitsFromRepr = [UInt8](decimalString.utf8)
        if digitsFromRepr.count > 1 {
            for digit in digitsFromRepr {
                if digit == Self.asciiPoint {
                    continue
                }
                guard (Self.asciiZero...Self.asciiNine).contains(digit) else {
                    throw BSONError.InvalidArgumentError(
                        message: "Syntax Error: \(digit) is not a digit '0'-'9' (\(Self.asciiZero)-\(Self.asciiNine))"
                    )
                }
                if digit == Self.asciiZero && leadingZero {
                    continue
                }
                if digit != Self.asciiZero && leadingZero {
                    // seen a non zero digit
                    leadingZero = false
                }
                digits.append(digit - Self.asciiZero)
            }
        } else {
            digits.append(digitsFromRepr[0] - Self.asciiZero)
        }
        return digits
    }

    private func toString() -> String {
        // swiftlint:disable:previous cyclomatic_complexity
        var exponent: Int
        var significandPrefix: Int

        // If the combination field starts with 0b11 it could be special (NaN/Inf)
        if self.value.hi.getBits(1...2) == 0b11 {
            if self.isInfinity {
                return (self.isNegative ? "-" : "") + "Infinity"
            }
            if self.isNaN {
                return "NaN"
            }
            // The number is neither NaN nor Inf
            // Decimal interchange floating-point formats c,2,ii
            exponent = Int(self.value.hi.getBits(3...16))
            significandPrefix = Int(self.value.hi.getBit(20) + 0b1000)
        } else {
            // Decimal interchange floating-point formats c,2,i
            exponent = Int(self.value.hi.getBits(1...14))
            significandPrefix = Int(self.value.hi.getBits(15...17))
        }

        exponent -= Self.exponentBias

        var significand128 = UInt128()

        // significand prefix (implied bits) combined with removing the combination and sign fields
        significand128.hi = UInt64((significandPrefix & 0xF) << 46) | self.value.hi.getBits(18...63)
        significand128.lo = self.value.lo

        // make a base 10 digits array from significand
        var significand = [Int]()

        var isZero = false

        if significand128.hi == 0 && significand128.lo == 0 {
            isZero = true
        } else if significand128.hi.getBits(0...31) >= 0x20000 {
            /*
             * The significand is non-canonical or zero.
             * In order to preserve compatibility with the densely packed decimal
             * format, the maximum value for the significand of decimal128 is
             * 1e34 - 1.  If the value is greater than 1e34 - 1, the IEEE 754
             * standard dictates that the significand is interpreted as zero.
             */
            isZero = true
        }

        if isZero {
            significand = [0]
        } else {
            for _ in 0...3 {
                var (quotient, remainder) = UInt128.divideBy1Billion(significand128)
                significand128 = quotient
                // We now have the 9 least significant digits.
                for _ in 0...8 {
                    significand.insert(remainder % 10, at: 0)
                    remainder /= 10
                }
            }
        }

        if !isZero, let firstNonZero = significand.firstIndex(where: { $0 != 0 }) {
            significand = [Int](significand.suffix(from: firstNonZero))
        }

        // Scientific - [-]d.ddde(+/-)dd or [-]de(+/-)dd
        // Regular    - ddd.ddd

        /*
         * The adjusted_exponent checks are dictated by the string conversion
         * specification.
         *
         * We must check exponent > 0, because if this is the case, the number
         * has trailing zeros.  However, we *cannot* output these trailing zeros,
         * because doing so would change the precision of the value, and would
         * change stored data if the string converted number is round tripped.
         */
        var representation = self.isNegative ? "-" : ""

        let adjusted_exponent = exponent + (significand.count - 1)
        if exponent > 0 || adjusted_exponent < -6 {
            // Scientific format
            representation += String(significand[0], radix: 10)
            representation += significand.count > 1 ? "." : ""
            representation += significand[1..<significand.count].map { String($0, radix: 10) }.joined(separator: "")
            representation += "E"
            representation += String(format: "%+d", adjusted_exponent)
        } else {
            // Regular format
            guard exponent != 0 else {
                representation += significand.map { String($0, radix: 10) }.joined(separator: "")
                return representation
            }

            var pointPosition = significand.count + exponent

            if pointPosition > 0 {
                // number isn't a fraction
                for _ in 0..<pointPosition {
                    representation += String(significand[0], radix: 10)
                    significand = Array(significand.dropFirst())
                }
            } else {
                representation += "0"
            }

            representation += "."

            while pointPosition < 0 {
                representation += "0"
                pointPosition += 1
            }

            representation += significand.map { String($0, radix: 10) }.joined(separator: "")
        }
        return representation
    }
}

extension BSONDecimal128: BSONValue {
    internal static var bsonType: BSONType { .decimal128 }

    internal var bson: BSON { .decimal128(self) }

    internal static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard
            let lo = buffer.readInteger(endianness: .little, as: UInt64.self),
            let hi = buffer.readInteger(endianness: .little, as: UInt64.self)
        else {
            throw BSONError.InternalError(message: "Cannot read 128-bits")
        }
        let decimal128 = Self(fromUInt128: UInt128(hi: hi, lo: lo))
        return .decimal128(decimal128)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.value.lo, endianness: .little, as: UInt64.self)
        buffer.writeInteger(self.value.hi, endianness: .little, as: UInt64.self)
    }
}