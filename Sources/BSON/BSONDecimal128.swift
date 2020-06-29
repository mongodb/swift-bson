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
        var productMid0 = leftHi * rightLo
        let productMid1 = leftLo * rightHi
        var productLo = leftLo * rightLo

        productHi += productMid0 >> 32
        productMid0 = (productMid0 & 0xFFFF_FFFF) + productMid1 + (productLo >> 32)

        productHi += (productMid0 >> 32)
        productLo = (productMid0 << 32) + (productLo & 0xFFFF_FFFF)

        return UInt128(hi: productHi, lo: productLo)
    }

    internal static func divideBy1Billion(_ numerator: UInt128) -> (quotient: UInt128, remainder: Int) {
        // swiftlint:disable:previous cyclomatic_complexity
        let DIVISOR: UInt64 = 1000 * 1000 * 1000
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
            case 0: quotient.hi = (((remainder / DIVISOR) << 32) | quotient.hi & 0x0000_0000_FFFF_FFFF)
            case 1: quotient.hi = (((remainder / DIVISOR) & 0xFFFF_FFFF) | quotient.hi & 0xFFFF_FFFF_0000_0000)
            case 2: quotient.lo = (((remainder / DIVISOR) << 32) | quotient.lo & 0x0000_0000_FFFF_FFFF)
            case 3: quotient.lo = (((remainder / DIVISOR) & 0xFFFF_FFFF) | quotient.lo & 0xFFFF_FFFF_0000_0000)
            default: _ = ()
            }
            /* Store the remainder */
            remainder %= DIVISOR
        }

        return (quotient: quotient, remainder: Int(remainder & 0xFFFF_FFFF))
    }
}

public struct BSONDecimal128: Equatable, Hashable, CustomStringConvertible {
    private static let DIGITS_RE = #"(?:\d+)"#
    private static let INDICATOR_RE = #"(?:e|E)"#
    private static let SIGN_RE = #"[+-]"#
    private static let INFINITY_RE = #"Infinity|Inf|infinity|inf"#
    private static let DECIMAL_PART_RE = "\(DIGITS_RE)\\.\(DIGITS_RE)?|\\.?\(DIGITS_RE)"
    private static let NAN_RE = #"NaN"#
    // swiftlint:disable line_length
    private static let EXPONENT_PART_RE = "\(INDICATOR_RE)(\(SIGN_RE))(\(DIGITS_RE))"
    private static let NUMERIC_VALUE_RE = "(\(SIGN_RE))?(?:(\(DECIMAL_PART_RE))(?:\(EXPONENT_PART_RE))?|(\(INFINITY_RE)))"
    // swiftlint:enable line_length
    public static let DECIMAL128_RE = "\(NUMERIC_VALUE_RE)|(\(NAN_RE))"

    private static let PRECISION_DIGITS = 34
    // NOTE: the min and max values are adjusted for when the decimal point is rounded out
    // e.g, 0.000...*10^-6143 == 0.000...*10^-6176
    // In the spec exp_max is 6144 so we use 6111
    private static let EXPONENT_MAX = 6111
    // In the spec exp_min is -6134 so we use -6176
    private static let EXPONENT_MIN = -6176
    private static let EXPONENT_BIAS = 6176

    private static let NEG_INFINITY = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
    private static let INFINITY = UInt128(hi: 0x7800_0000_0000_0000, lo: 0)
    private static let NAN = UInt128(hi: 0x7C00_0000_0000_0000, lo: 0)

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
    /// Determines if the value is Not a Number
    private var isNaN: Bool { ((self.value.hi & 0x7F00_0000_0000_0000) >> 56) == 0b11111 }
    /// Determines if the value is Infinity
    private var isInf: Bool { ((self.value.hi & 0x7F00_0000_0000_0000) >> 56) == 0b11110 }

    internal init(fromUInt128 value: UInt128) {
        self.value = value
    }

    public init(_ data: String) throws {
        // swiftlint:disable:previous cyclomatic_complexity
        let regex = try NSRegularExpression(pattern: BSONDecimal128.DECIMAL128_RE)
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
            self.value = BSONDecimal128.NAN
            return
        }

        let isInfinity = match.range(at: REGroups.infinity.rawValue)
        if isInfinity.location != NSNotFound {
            if sign < 0 {
                self.value = BSONDecimal128.NEG_INFINITY
                return
            }
            self.value = BSONDecimal128.INFINITY
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
        var digits = try BSONDecimal128.convertToDigitsArray(decimalPart)

        var exponent = 0
        let exponentPartRange = match.range(at: REGroups.exponentPart.rawValue)
        if exponentPartRange.location != NSNotFound, let range = Range(exponentPartRange, in: data) {
            exponent = exponentSign * (Int(data[range]) ?? 0)
        }
        if decimalPart.contains(".") {
            let pointIndex = decimalPart.firstIndex(of: ".") ?? decimalPart.endIndex
            exponent -= decimalPart.distance(from: pointIndex, to: decimalPart.endIndex) - 1
            if exponent < BSONDecimal128.EXPONENT_MIN {
                exponent = BSONDecimal128.EXPONENT_MIN
            }
        }

        while exponent > BSONDecimal128.EXPONENT_MAX && digits.count <= BSONDecimal128.PRECISION_DIGITS {
            // Exponent is too large, try shifting zeros into the coefficient
            digits.append(0)
            exponent -= 1
        }

        while exponent < BSONDecimal128.EXPONENT_MIN && !digits.isEmpty {
            // Exponent is too small, try taking zeros off the coefficient
            if digits.count == 1 && digits[0] == 0 {
                exponent = BSONDecimal128.EXPONENT_MIN
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

        guard (exponent >= BSONDecimal128.EXPONENT_MIN) && (exponent <= BSONDecimal128.EXPONENT_MAX) else {
            throw BSONError.InvalidArgumentError(message: "Rounding Error: Cannot round exponent \(exponent) further")
        }

        guard digits.count <= BSONDecimal128.PRECISION_DIGITS else {
            throw BSONError.InvalidArgumentError(
                message: "Overflow Error: Value cannot exceed \(BSONDecimal128.PRECISION_DIGITS) digits"
            )
        }

        var significand = UInt128()

        if digits.isEmpty {
            significand.hi = 0
            significand.lo = 0
        }

        let lo_digits = Array(digits.suffix(17))
        let hi_digits = Array(digits.dropLast(17))

        if !lo_digits.isEmpty {
            significand.lo = UInt64(lo_digits[0])
            for digit in lo_digits[1...] {
                significand.lo *= 10
                significand.lo += UInt64(digit)
            }
        }

        if !hi_digits.isEmpty {
            significand.hi = UInt64(hi_digits[0])
            for digit in hi_digits[1...] {
                significand.hi *= 10
                significand.hi += UInt64(digit)
            }
        }

        var product = UInt128.multiply(significand.hi, by: 100_000_000_000_000_000)
        product.lo += significand.lo

        if product.lo < significand.lo {
            product.hi += 1
        }

        let biased_exponent = exponent + BSONDecimal128.EXPONENT_BIAS

        self.value = UInt128()

        // Encode combination, exponent, and significand.
        if (product.hi >> 49) & 1 == 1 {
            // Encode '11' into bits 1 to 3
            self.value.hi |= (0b11 << 61)
            self.value.hi |= UInt64(biased_exponent & 0x3FFF) << 47
            self.value.hi |= product.hi & 0x7FFF_FFFF_FFFF
        } else {
            self.value.hi |= UInt64(biased_exponent & 0x3FFF) << 49
            self.value.hi |= product.hi & 0x1_FFFF_FFFF_FFFF
        }

        self.value.lo = product.lo

        if sign < 0 {
            self.value.hi |= 0x8000_0000_0000_0000
        }
    }

    private static func convertToDigitsArray(_ decimalString: String) throws -> [UInt8] {
        var leadingZero = true
        var digits: [UInt8] = []

        let asciiZero = Character("0").asciiValue ?? 48
        let asciiNine = Character("9").asciiValue ?? 57
        let asciiPoint = Character(".").asciiValue ?? 46

        let digitsFromRepr = [UInt8](decimalString.utf8)
        if digitsFromRepr.count > 1 {
            for digit in digitsFromRepr {
                if digit == asciiPoint {
                    continue
                }
                if (digit < asciiZero) && (digit > asciiNine) {
                    throw BSONError.InvalidArgumentError(message: "Syntax Error: \(digit) is not a digit 0-9")
                }
                if digit == asciiZero && leadingZero {
                    continue
                }
                if digit != asciiZero && leadingZero {
                    // seen a non zero digit
                    leadingZero = false
                }
                digits.append(digit - asciiZero)
            }
        } else {
            digits.append(digitsFromRepr[0] - asciiZero)
        }
        return digits
    }

    private func toString() -> String {
        // swiftlint:disable:previous cyclomatic_complexity
        /**
         * BSON_DECIMAL128_STRING:
         *
         * The length of a decimal128 string.
         *
         * 1  for the sign
         * 35 for digits and radix
         * 2  for exponent indicator and sign
         * 4  for exponent digits
         * BSON_DECIMAL128_STRING 42
         */
        var exponent: Int
        var sig_prefix: Int

        let COMBINATION_INFINITY = 30
        let COMBINATION_NAN = 31

        let combination = (self.value.hi >> 58) & 0x1F
        if (combination >> 3) == 0b11 {
            if combination == COMBINATION_INFINITY {
                return self.isNegative ? "-" : "" + "Infinity"
            }
            if combination == COMBINATION_NAN {
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

        exponent -= BSONDecimal128.EXPONENT_BIAS

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
                if remainder == 0 {
                    continue
                }
                for _ in 0...8 {
                    significand.insert(remainder % 10, at: 0)
                    remainder /= 10
                }
            }
        }

        /* Scientific - [-]d.dddE(+/-)dd or [-]dE(+/-)dd */
        /* Regular    - ddd.ddd */

        /*
         * The scientific exponent checks are dictated by the string conversion
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
            representation += "e"
            representation += String(format: "%+d", exponent)
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
        let decimal128 = BSONDecimal128(fromUInt128: UInt128(hi: hi, lo: lo))
        return .decimal128(decimal128)
    }

    internal func write(to buffer: inout ByteBuffer) {
        buffer.writeInteger(self.value.lo, endianness: .little, as: UInt64.self)
        buffer.writeInteger(self.value.hi, endianness: .little, as: UInt64.self)
    }
}
