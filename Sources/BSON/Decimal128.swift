import Foundation
import NIO

public struct UInt128: Equatable, Hashable {
    /// The high order 64 bits
    public var hi: UInt64
    /// The low order 64 bits
    public var lo: UInt64

    public static func multiply(_ left: UInt64, by right: UInt64) -> UInt128 {
        let (product, didOverflow) = left.multipliedReportingOverflow(by: right)
        if !didOverflow {
            return UInt128(hi: 0, lo: product)
        }

        let leftHi = UInt64(UInt32(left >> 32))
        let leftLo = UInt64(UInt32(left) & UInt32.max)

        let rightHi = UInt64(UInt32(right >> 32))
        let rightLo = UInt64(UInt32(right) & UInt32.max)

        var productHi = leftHi * rightHi
        var productMid0 = leftHi * rightLo
        let productMid1 = leftLo * rightHi
        var productLo = leftLo * rightLo

        productHi += productMid0 >> 32
        productMid0 += productMid1 + (productLo >> 32)

        productHi += productMid0 >> 32
        productLo += productMid0 << 32

        return UInt128(hi: productHi, lo: productLo)
    }
}

public struct Decimal128: BSONValue, Equatable, Hashable, CustomStringConvertible {
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

    private static let PERCISION_DIGITS = 34
    private static let EXPONENT_MAX = 6144
    private static let EXPONENT_BIAS = EXPONENT_MAX + PERCISION_DIGITS - 2
    private static let EXPONENT_MIN = 1 - EXPONENT_MAX

    private static let NEG_INFINITY = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
    private static let INFINITY = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
    private static let NAN = UInt128(hi: 0x7C00_0000_0000_0000, lo: 0)

    private enum REGroups: Int, CaseIterable {
        case sign = 1
        case decimalPart = 2
        case exponentSign = 3
        case exponentPart = 4
        case infinity = 5
        case nan = 6
    }

    public enum Decimal128Errors: Error {
        case Overflow
        case Underflow
        case Clamping
        case Rounding
        case Syntax
    }

    public var bsonType: BSONType { .decimal128 }

    public var bson: BSON { .decimal128(self) }

    public var description: String { fatalError("Unimplemented") }

    /// Holder for raw decimal128 value
    public var value: UInt128

    /// Determines if the value is Not a Number
    public var isNaN: Bool { Decimal128.NAN == self.value }
    /// Determines if the value is Infinity
    public var isInf: Bool { Decimal128.INFINITY == self.value || Decimal128.NEG_INFINITY == self.value }

    internal init(fromUInt128 value: UInt128) {
        self.value = value
    }

    public init(fromString repr: String) throws {
        // swiftlint:disable:previous cyclomatic_complexity
        let regex = try NSRegularExpression(pattern: Decimal128.DECIMAL128_RE)
        let wholeRepr = NSRange(repr.startIndex..<repr.endIndex, in: repr)
        guard let match: NSTextCheckingResult = regex.firstMatch(in: repr, range: wholeRepr) else {
            throw Decimal128Errors.Syntax
        }

        var sign = 1
        let signRange: NSRange = match.range(at: REGroups.sign.rawValue)
        if signRange.location != NSNotFound, let range = Range(signRange, in: repr) {
            sign = String(repr[range]) == "-" ? -1 : 1
        }

        let isNaN = match.range(at: REGroups.nan.rawValue)
        if isNaN.location != NSNotFound {
            self.value = UInt128(hi: 0x7C00_0000_0000_0000, lo: 0)
            return
        }

        let isInfinity = match.range(at: REGroups.infinity.rawValue)
        if isInfinity.location != NSNotFound {
            if sign < 0 {
                self.value = UInt128(hi: 0xF800_0000_0000_0000, lo: 0)
                return
            }
            self.value = UInt128(hi: 0x7800_0000_0000_0000, lo: 0)
            return
        }

        var exponentSign = 1
        let exponentSignRange = match.range(at: REGroups.exponentSign.rawValue)
        if exponentSignRange.location != NSNotFound, let range = Range(exponentSignRange, in: repr) {
            exponentSign = String(repr[range]) == "-" ? -1 : 1
        }

        let decimalPartNSRange = match.range(at: REGroups.decimalPart.rawValue)
        guard decimalPartNSRange.location != NSNotFound,
            let decimalPartRange = Range(decimalPartNSRange, in: repr) else {
            throw Decimal128Errors.Syntax
        }
        let decimalPart = String(repr[decimalPartRange])
        var digits = try Decimal128.convertToDigitsArray(decimalPart)

        var exponent = 0
        let exponentPartRange = match.range(at: REGroups.exponentPart.rawValue)
        if exponentPartRange.location != NSNotFound, let range = Range(exponentPartRange, in: repr) {
            exponent = exponentSign * (Int(repr[range]) ?? 0)
        }
        if decimalPart.contains(".") {
            let pointIndex = decimalPart.firstIndex(of: ".") ?? decimalPart.endIndex
            exponent -= decimalPart.distance(from: pointIndex, to: decimalPart.endIndex) - 1
            if exponent < Decimal128.EXPONENT_MIN {
                exponent = Decimal128.EXPONENT_MIN
            }
        }

        guard !digits.isEmpty else {
            // This is not possible because of the regex
            throw Decimal128Errors.Syntax
        }

        while exponent > Decimal128.EXPONENT_MAX && digits.count <= Decimal128.PERCISION_DIGITS {
            // Exponent is too large, try shifting zeros into the coeffecient
            digits.append(0)
            exponent -= 1
        }

        while exponent < Decimal128.EXPONENT_MIN && !digits.isEmpty {
            // Exponent is too small, try taking zeros off the coeffcient
            if digits.count == 1 && digits[0] == 0 {
                // throw Decimal128Errors.Clamping (this is allowed though b/c its zero)
                exponent = Decimal128.EXPONENT_MIN
                break
            }

            if digits.last == 0 {
                digits.removeLast()
                exponent += 1
                continue
            }

            if digits.last != 0 {
                // We don't end in a zero and our exponent is too small
                throw Decimal128Errors.Underflow
            }
        }

        guard (exponent >= Decimal128.EXPONENT_MIN) && (exponent <= Decimal128.EXPONENT_MAX) else {
            throw Decimal128Errors.Rounding
        }

        guard digits.count <= Decimal128.PERCISION_DIGITS else {
            throw Decimal128Errors.Overflow
        }

        var significand = UInt128(hi: 0x0, lo: 0x0)

        if digits.isEmpty {
            significand.hi = 0
            significand.lo = 0
        }

        if digits.count < 17 {
            significand.lo = UInt64(digits[0])
            for digit in digits[1...] {
                significand.lo *= 10
                significand.lo += UInt64(digit)
            }
        } else if digits.count > 17 {
            significand.hi = UInt64(digits[0])
            for digit in digits[1..<18] {
                significand.hi *= 10
                significand.hi += UInt64(digit)
            }

            significand.lo = UInt64(digits[18])
            for digit in digits[19...] {
                significand.lo *= 10
                significand.lo += UInt64(digit)
            }
        }

        self.value = UInt128(hi: 0, lo: significand.lo)
        let biased_exponent = exponent + Decimal128.EXPONENT_BIAS

        // Encode combination, exponent, and significand.
        if (significand.hi >> 49) & 1 == 1 {
            // Encode '11' into bits 1 to 3
            self.value.hi |= (0b11 << 61)
            self.value.hi |= UInt64(biased_exponent & 0x3FFF) << 47
            self.value.hi |= significand.hi & 0x7FFF_FFFF_FFFF
        } else {
            self.value.hi |= UInt64(biased_exponent & 0x3FFF) << 49
            self.value.hi |= significand.hi & 0x1_FFFF_FFFF_FFFF
        }

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
                    throw Decimal128Errors.Syntax
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

    public static func read(from buffer: inout ByteBuffer) throws -> BSON {
        guard
            let hi = buffer.readInteger(endianness: .little, as: UInt64.self),
            let lo = buffer.readInteger(endianness: .little, as: UInt64.self)
        else {
            throw InternalError(message: "Cannot read 64-bit integer")
        }
        let decimal128 = Decimal128(fromUInt128: UInt128(hi: hi, lo: lo))
        return .decimal128(decimal128)
    }

    public func write(to buffer: inout ByteBuffer) throws {
        buffer.writeInteger(self.value.lo, endianness: .little, as: UInt64.self)
        buffer.writeInteger(self.value.hi, endianness: .little, as: UInt64.self)
    }
}
