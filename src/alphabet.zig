//! Provides [Alphabet] and constants for alphabets commonly used in the wild.

const std = @import("std");

/// Unsurprisingly, there are 64 symbols in a Base64 alphabet.
const ALPHABET_LEN: usize = 64;

/// Pad symbol for non-weird alphabets.
pub const PADDING_SYMBOL: Symbol = .{ .s = '=' };

/// An alphabet defines the 64 ASCII characters (symbols) used for base64.
///
/// Common alphabets are provided as constants
///
/// # Examples
///
/// Building and using a custom Alphabet:
///
/// ```
/// const base64 = @import("base64");
/// const custom = try base64.alphabet.Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/");
pub const Alphabet = struct {
    /// All bytes are valid symbols, but left as u8 to allow `.as_str()` to work.
    symbols: [ALPHABET_LEN]u8,
    padding: Symbol,

    /// Create an `Alphabet` from a string of 64 unique printable ASCII bytes with `=` as the
    /// padding symbol.
    ///
    /// The padding symbol `=` is not allowed in the alphabet.
    ///
    /// See [`Self::new_with_padding`] if a non-default padding symbol is needed.
    pub fn new(alphabet: []const u8) ParseAlphabetResult {
        return Alphabet.new_with_padding(alphabet, PADDING_SYMBOL);
    }

    /// Performs no checks so that it can be const.
    /// Used only for known-valid strings.
    fn from_str_unchecked(alphabet: []const u8, padding: Symbol) Alphabet {
        var symbols: [ALPHABET_LEN]u8 = @splat(0);
        const source_bytes = alphabet;

        // a way to copy that's allowed in const fn
        var index: usize = 0;
        while (index < ALPHABET_LEN) {
            symbols[index] = source_bytes[index];
            index += 1;
        }

        return .{ .symbols = symbols, .padding = padding };
    }

    /// Create an `Alphabet` from a string of 64 unique printable ASCII bytes, with a custom
    /// padding symbol.
    ///
    /// The padding symbol must not appear in the alphabet.
    ///
    /// This is meant for strange alphabets that don't use `=` as the padding symbol.
    pub fn new_with_padding(
        alphabet: []const u8,
        padding: Symbol,
    ) ParseAlphabetResult {
        if (alphabet.len != ALPHABET_LEN) {
            return .{ .failure = .{
                .invalid_length = {},
            } };
        }

        {
            var index: usize = 0;
            while (index < ALPHABET_LEN) {
                const byte = alphabet[index];

                if (!is_valid_b64_symbol(byte)) {
                    return .{ .failure = .{ .unprintable_byte = byte } };
                }
                if (byte == padding.as_u8()) {
                    return .{ .failure = .{ .reserved_byte = byte } };
                }

                // Check for duplicates while staying within what const allows.
                // It's n^2, but only over 64 hot bytes, and only once, so it's likely in the single digit
                // microsecond range.

                var probe_index: usize = 0;
                while (probe_index < ALPHABET_LEN) {
                    if (probe_index != index and byte == alphabet[probe_index]) {
                        return .{ .failure = .{ .duplicated_byte = byte } };
                    }

                    probe_index += 1;
                }

                index += 1;
            }
        }

        return .{ .success = Alphabet.from_str_unchecked(alphabet, padding) };
    }

    /// The 64 symbols of the alphabet (excluding padding).
    pub fn get_symbols(self: Alphabet) [ALPHABET_LEN]Symbol {
        var symbols: [ALPHABET_LEN]Symbol = undefined;
        for (self.symbols, 0..) |s, i| {
            symbols[i] = Symbol{ .s = s };
        }

        return symbols;
    }

    /// The symbol used for padding.
    pub fn get_padding(self: Alphabet) Symbol {
        return self.padding;
    }
};

pub const ParseAlphabetResult = union(enum) {
    success: Alphabet,
    failure: ParseAlphabetError,
};

/// An ASCII printable byte suitable for use as a base64 symbol in an alphabet or as custom padding.
///
/// This doesn't mean that a particular symbol is used in any particular alphabet, just that it
/// could be used in one.
pub const Symbol = struct {
    s: u8,

    /// Returns `Some` if `symbol` is a valid printable ASCII symbol, otherwise `None`.
    pub fn init(symbol: u8) ?Symbol {
        if (is_valid_b64_symbol(symbol)) {
            return .{ .s = symbol };
        } else {
            return null;
        }
    }

    /// Returns the symbol as an ASCII byte.
    pub fn as_u8(self: Symbol) u8 {
        return self.s;
    }
};

/// Must be ascii printable. 127 (DEL) is commonly considered printable
/// for some reason but clearly unsuitable for base64.
pub fn is_valid_b64_symbol(byte: u8) bool {
    return byte >= 32 and byte <= 126;
}

/// Possible errors when constructing an [Alphabet] from a `str`.
pub const ParseAlphabetError = union(enum) {
    /// Alphabets must be 64 ASCII bytes
    invalid_length: void,
    /// All bytes must be unique
    duplicated_byte: u8,
    /// All bytes must be printable (in the range `[32, 126]`).
    unprintable_byte: u8,
    /// Alphabet cannot contain the pad symbol (`=` by default)
    reserved_byte: u8,
};

/// The standard alphabet (with `+` and `/`) specified in [RFC 4648][].
///
/// [RFC 4648]: https://datatracker.ietf.org/doc/html/rfc4648#section-4
pub const STANDARD: Alphabet = Alphabet.from_str_unchecked(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    PADDING_SYMBOL,
);

/// The URL-safe alphabet (with `-` and `_`) specified in [RFC 4648][].
///
/// [RFC 4648]: https://datatracker.ietf.org/doc/html/rfc4648#section-5
pub const URL_SAFE: Alphabet = Alphabet.from_str_unchecked(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
    PADDING_SYMBOL,
);

/// The `crypt(3)` alphabet (with `.` and `/` as the _first_ two characters).
///
/// Not standardized, but folk wisdom on the net asserts that this alphabet is what crypt uses.
pub const CRYPT: Alphabet = Alphabet.from_str_unchecked(
    "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
    PADDING_SYMBOL,
);

/// The bcrypt alphabet.
pub const BCRYPT: Alphabet = Alphabet.from_str_unchecked(
    "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
    PADDING_SYMBOL,
);

/// The alphabet used in IMAP-modified UTF-7 (with `+` and `,`).
///
/// See [RFC 3501](https://tools.ietf.org/html/rfc3501#section-5.1.3)
pub const IMAP_MUTF7: Alphabet = Alphabet.from_str_unchecked(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+,",
    PADDING_SYMBOL,
);

/// The alphabet used in `BinHex` 4.0 files.
///
/// See [BinHex 4.0 Definition](http://files.stairways.com/other/binhex-40-specs-info.txt)
pub const BIN_HEX: Alphabet = Alphabet.from_str_unchecked(
    "!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr",
    PADDING_SYMBOL,
);

//
// #[cfg(test)]
// mod tests {
//     use crate::alphabet::*;
//     use core::convert::TryFrom as _;
//
test "detects_duplicate_start" {
    try std.testing.expectEqual(
        ParseAlphabetResult{
            .failure = ParseAlphabetError{
                .duplicated_byte = 'A',
            },
        },
        Alphabet.new("AACDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
    );
}

test "detects_duplicate_end" {
    try std.testing.expectEqual(ParseAlphabetResult{ .failure = ParseAlphabetError{
        .duplicated_byte = '/',
    } }, Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789//"));
}
test "detects_duplicate_middle" {
    try std.testing.expectEqual(ParseAlphabetResult{ .failure = ParseAlphabetError{ .duplicated_byte = 'Z' } }, Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZZbcdefghijklmnopqrstuvwxyz0123456789+/"));
}

test "detects_length" {
    try std.testing.expectEqual(ParseAlphabetResult{ .failure = ParseAlphabetError{ .invalid_length = {} } }, Alphabet.new(
        "xxxxxxxxxABCDEFGHIJKLMNOPQRSTUVWXYZZbcdefghijklmnopqrstuvwxyz0123456789+/",
    ));
}

test "detects_padding" {
    try std.testing.expectEqual(ParseAlphabetResult{ .failure = ParseAlphabetError{ .reserved_byte = '=' } }, Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+="));
}

test "detects_unprintable" {
    // form feed
    try std.testing.expectEqual(ParseAlphabetResult{ .failure = ParseAlphabetError{ .unprintable_byte = 0x0c } }, Alphabet.new("\x0cBCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"));
}