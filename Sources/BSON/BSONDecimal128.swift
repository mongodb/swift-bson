import Foundation
import NIO

internal struct UInt128: Equatable, Hashable {
    /// The high order 64 bits
    internal var hi: UInt64
    /// The low order 64 bits
    internal var lo: UInt64

    internal init(hi: UInt64, lo: UInt64) {
        self.hi = hi
        self.lo = lo
    }

    internal init(_ value: UInt128) {
        self.hi = value.hi
        self.lo = value.lo
    }

    internal init() {
        self.hi = 0
        self.lo = 0
    }

    internal static func multiply(_ left: UInt64, by right: UInt64) -> UInt128 {
        let (product, didOverflow) = left.multipliedReportingOverflow(by: right)
        if !didOverflow {
            return UInt128(hi: 0, lo: product)
        }

        let leftHi = left >> 32
        let leftLo = left & 0xFFFF_FFFF

        let rightHi = right >> 32
        let rightLo = right & 0xFFFF_FFFF

        var productHi = leftHi * rightHi
        let productMid0 = leftHi * rightLo
        let productMid1 = leftLo * rightHi
        var productLo = leftLo * rightLo

        productHi += productMid0 >> 32
        let productPartial = (productMid0 & 0xFFFF_FFFF) + productMid1 + (productLo >> 32)

        productHi += (productPartial >> 32)
        productLo = (productPartial << 32) + (productLo & 0xFFFF_FFFF)

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
            /* Adjust remainder to match value of next dividend */
            remainder <<= 32
            /* Add the divided to remainder */
            var quotient_i: UInt64
            switch i {
            case 0: quotient_i = (quotient.hi & 0xFFFF_FFFF_0000_0000) >> 32
            case 1: quotient_i = (quotient.hi & 0x0000_0000_FFFF_FFFF)
            case 2: quotient_i = (quotient.lo & 0xFFFF_FFFF_0000_0000) >> 32
            case 3: quotient_i = (quotient.lo & 0x0000_0000_FFFF_FFFF)
            default: quotient_i = 0
            }
            remainder += quotient_i
            // quotient[i] = Int(remainder / DIVISOR)
            switch i {
            case 0: quotient.hi = (((remainder / denominator) << 32) | quotient.hi & 0x0000_0000_FFFF_FFFF)
            case 1: quotient.hi = (((remainder / denominator) & 0xFFFF_FFFF) | quotient.hi & 0xFFFF_FFFF_0000_0000)
            case 2: quotient.lo = (((remainder / denominator) << 32) | quotient.lo & 0x0000_0000_FFFF_FFFF)
            case 3: quotient.lo = (((remainder / denominator) & 0xFFFF_FFFF) | quotient.lo & 0xFFFF_FFFF_0000_0000)
            default: _ = ()
            }
            /* Store the remainder */
            remainder %= denominator
        }

        return (quotient: quotient, remainder: Int(remainder & 0xFFFF_FFFF))
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
    private static let numbericValueRegex = "(\(signRegex))?(?:(\(decimalRegex))(?:\(exponentRegex))?|(\(infinityRegex)))"
    public static let decimal128Regex = "\(numbericValueRegex)|(\(nanRegex))"
    // swiftlint:enable line_length

    // The precision of the Decimal128 format
    private static let significandDigits = 34
    // NOTE: the min and max values are adjusted for when the decimal point is rounded out
    // e.g, 1.000...*10^-6143 == 1000...*10^-6176
    // In the spec exp_max is 6144 so we use 6111
    private static let exponentMax = 6111
    // In the spec exp_min is -6134 so we use -6176
    private static let exponentMin = -6176
    // The sum of the exponent and a constant (bias) chosen to make the biased exponent’s range non-negative.
    private static let exponentBias = 6176

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

    /// Determines if the value is 0
    private var isNegative: Bool { (self.value.hi >> 63) == 1 }

    /// Indicators in the combination field that determine number type
    private static let combinationNaN = 0b11111
    private static let combinationInfinity = 0b11110

    /// Determines if the value is Not a Number
    private var isNaN: Bool { ((self.value.hi >> 58) & 0x1F) == Self.combinationNaN }
    /// Determines if the value is Infinity
    private var isInfinity: Bool { ((self.value.hi >> 58) & 0x1F) == Self.combinationInfinity }

    internal init(fromUInt128 value: UInt128) {
        self.value = value
    }

    public init(_ data: String) throws {
        // swiftlint:disable:previous cyclomatic_complexity
        let regex = try NSRegularExpression(pattern: Self.decimal128Regex)
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
            exponent -= decimalPart.distance(from: pointIndex, to: decimalPart.endIndex) - 1
            if exponent < Self.exponentMin {
                exponent = Self.exponentMin
            }
        }

        while exponent > Self.exponentMax && digits.count <= Self.significandDigits {
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

        guard digits.count <= Self.significandDigits else {
            throw BSONError.InvalidArgumentError(
                message: "Overflow Error: Value cannot exceed \(Self.significandDigits) digits"
            )
        }

        var significand = UInt128()

        if digits.isEmpty {
            significand.hi = 0
            significand.lo = 0
        }

        let loDigits = Array(digits.suffix(17))
        let hiDigits = Array(digits.dropLast(17))

        if !loDigits.isEmpty {
            significand.lo = UInt64(loDigits[0])
            for digit in loDigits[1...] {
                significand.lo *= 10
                significand.lo += UInt64(digit)
            }
        }

        if !hiDigits.isEmpty {
            significand.hi = UInt64(hiDigits[0])
            for digit in hiDigits[1...] {
                significand.hi *= 10
                significand.hi += UInt64(digit)
            }
        }

        var product = UInt128.multiply(significand.hi, by: 100_000_000_000_000_000)
        product.lo += significand.lo

        if product.lo < significand.lo {
            product.hi += 1
        }

        let biasedExponent = exponent + Self.exponentBias

        self.value = UInt128()

        // Encode combination, exponent, and significand.
        if (product.hi >> 49) & 1 == 1 {
            // The significand has the implicit (0b100) at the
            // begining of the trailing significand field

            // Ensure we encode '0b11' into bits 1 to 3
            self.value.hi |= (0b11 << 61)
            self.value.hi |= UInt64(biasedExponent & 0x3FFF) << 47
            self.value.hi |= product.hi & 0x7FFF_FFFF_FFFF
        } else {
            // The significand has the implicit (0b0) at the
            // begining of the trailing significand field
            self.value.hi |= UInt64(biasedExponent & 0x3FFF) << 49
            self.value.hi |= product.hi & 0x1_FFFF_FFFF_FFFF
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
        var sig_prefix: Int

        let combination = (self.value.hi >> 58) & 0x1F
        if (combination >> 3) == 0b11 {
            if self.isInfinity {
                return (self.isNegative ? "-" : "") + "Infinity"
            }
            if self.isNaN {
                return "NaN"
            }
            // Decimal interchange floating-point formats c,2,ii
            exponent = Int((self.value.hi >> 47) & 0x3FFF)
            sig_prefix = Int(((self.value.hi >> 46) & 0b1) + 0b1000)
        } else {
            // Decimal interchange floating-point formats c,2,i
            exponent = Int((self.value.hi >> 49) & 0x3FFF)
            sig_prefix = Int((self.value.hi >> 46) & 0x7)
        }

        exponent -= Self.exponentBias

        var significand128 = UInt128()

        significand128.hi = UInt64((sig_prefix & 0xF) << 46) | self.value.hi & 0x0000_3FFF_FFFF_FFFF
        significand128.lo = self.value.lo

        /// make a base 10 digits array from significand
        var significand = [Int]()

        var isZero = false

        if significand128.hi == 0 && significand128.lo == 0 {
            isZero = true
        } else if (significand128.hi >> 32) >= (1 << 17) {
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
                /* We now have the 9 least significant digits. */
                for _ in 0...8 {
                    significand.insert(remainder % 10, at: 0)
                    remainder /= 10
                }
            }
        }

        if !isZero, let firstNonZero = significand.firstIndex(where: { $0 != 0 }) {
            significand = [Int](significand.suffix(from: firstNonZero))
        }

        /* Scientific - [-]d.ddde(+/-)dd or [-]de(+/-)dd */
        /* Regular    - ddd.ddd */

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
                /// number isn't a fraction
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
