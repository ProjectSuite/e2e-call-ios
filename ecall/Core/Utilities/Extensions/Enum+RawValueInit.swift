import Foundation

// MARK: - Generic Raw Value Initializable Protocol
/// Protocol for enums that can be initialized from raw value with fallback
///
/// This protocol provides a common pattern for enums with any raw value type
/// that need to be initialized from optional raw values with a default fallback.
///
/// ## Usage
/// ```swift
/// // String enum
/// enum MyStringEnum: String, RawValueInitializable {
///     case option1
///     case option2
///     case option3
///
///     static var defaultCase: MyStringEnum { .option1 }
/// }
///
/// // Int enum
/// enum MyIntEnum: Int, RawValueInitializable {
///     case first = 1
///     case second = 2
///     case third = 3
///
///     static var defaultCase: MyIntEnum { .first }
/// }
///
/// // Usage
/// let stringEnum = MyStringEnum(fromRawValue: "option2") // .option2
/// let intEnum = MyIntEnum(fromRawValue: 2) // .second
/// let invalidEnum = MyStringEnum(fromRawValue: "invalid") // .option1 (default)
/// ```
///
/// ## Benefits
/// - Eliminates repetitive `init(fromRawValue: T?)` implementations
/// - Provides consistent behavior across all enums with any raw value type
/// - Reduces code duplication and potential bugs
/// - Makes the default case explicit and required
/// - Generic support for String, Int, Double, Bool, etc.
protocol RawValueInitializable: RawRepresentable {
    /// The default case to use when raw value is invalid or nil
    static var defaultCase: Self { get }
}

// MARK: - Generic Default Implementation
extension RawValueInitializable {
    /// Common initializer for enums with any raw value type
    /// - Parameter fromRawValue: Optional raw value
    /// - Returns: Enum case or default case if raw value is invalid
    init(fromRawValue: RawValue?) {
        if let rawValue = fromRawValue,
           let enumCase = Self(rawValue: rawValue) {
            self = enumCase
        } else {
            self = Self.defaultCase
        }
    }
}

// MARK: - Convenience Extensions for Common Types
extension RawValueInitializable where RawValue == String {
    /// Convenience initializer for String enums from optional String
    init(fromString: String?) {
        self.init(fromRawValue: fromString)
    }
}

extension RawValueInitializable where RawValue == Int {
    /// Convenience initializer for Int enums from optional Int
    init(fromInt: Int?) {
        self.init(fromRawValue: fromInt)
    }
}

extension RawValueInitializable where RawValue == Double {
    /// Convenience initializer for Double enums from optional Double
    init(fromDouble: Double?) {
        self.init(fromRawValue: fromDouble)
    }
}

extension RawValueInitializable where RawValue == Bool {
    /// Convenience initializer for Bool enums from optional Bool
    init(fromBool: Bool?) {
        self.init(fromRawValue: fromBool)
    }
}
