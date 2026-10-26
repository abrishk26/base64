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
/// const custom = try base64.alphabet.Alphabet.new(
///     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
/// );
/// ```
pub const Alphabet = struct {
    /// All bytes are valid symbols, but left as u8 to allow `.as_str()` to work.
    symbols: [ALPHABET_LEN]u8,
    lookup: [256]u8,
    padding: Symbol,

    /// Create an `Alphabet` from a string of 64 unique printable ASCII bytes with `=` as the
    /// padding symbol.
    ///
    /// The padding symbol `=` is not allowed in the alphabet.
    ///
    /// See [`Self::new_with_padding`] if a non-default padding symbol is needed.
    pub fn new(alphabet: []const u8) ParseAlphabetError!Alphabet {
        return Alphabet.new_with_padding(alphabet, PADDING_SYMBOL);
    }

    /// Performs no checks so that it can be const.
    /// Used only for known-valid strings.
    fn from_str_unchecked(alphabet: []const u8, padding: Symbol) Alphabet {
        var symbols: [ALPHABET_LEN]u8 = @splat(0);
        var lookup: [256]u8 = @splat(255);

        for (alphabet, 0..) |symbol, index| {
            symbols[index] = symbol;
        }

        for (symbols, 0..) |symbol, index| {
            lookup[symbol] = @intCast(index);
        }

        return .{ .symbols = symbols, .lookup = lookup, .padding = padding };
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
    ) ParseAlphabetError!Alphabet {
        if (alphabet.len != ALPHABET_LEN) return error.InvalidLength;

        const pad_byte = padding.as_u8();
        for (alphabet, 0..) |byte, index| {
            if (!is_valid_b64_symbol(byte)) return error.UnprintableByte;
            if (byte == pad_byte) return error.ReservedByte;

            // Only need to check earlier bytes — later ones will check against this one.
            for (alphabet[0..index]) |prev| {
                if (prev == byte) return error.DuplicatedByte;
            }
        }
        return Alphabet.from_str_unchecked(alphabet, padding);
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

/// An ASCII printable byte suitable for use as a base64 symbol in an alphabet or as custom padding.
///
/// This doesn't mean that a particular symbol is used in any particular alphabet, just that it
/// could be used in one.
pub const Symbol = struct {
    s: u8,

    /// Returns the symbol as `?Symbol`, or `null` if `symbol` is not a valid
    /// printable ASCII byte.
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

/// Possible errors when constructing an [Alphabet] from a string.
pub const ParseAlphabetError = error{
    /// Alphabets must be 64 bytes long.
    InvalidLength,
    /// All 64 bytes must be unique.
    DuplicatedByte,
    /// All bytes must be printable ASCII (`[32, 126]`).
    UnprintableByte,
    /// The padding symbol must not appear in the alphabet.
    ReservedByte,
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

const testing = std.testing;

test "new accepts the standard alphabet" {
    const a = try Alphabet.new(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    );

    try testing.expectEqual(@as(u8, '='), a.padding.as_u8());
    try testing.expectEqualStrings(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        a.symbols[0..],
    );
}

test "new_with_padding accepts a custom padding symbol" {
    const a = try Alphabet.new_with_padding(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        .{ .s = '@' },
    );

    try testing.expectEqual(@as(u8, '@'), a.padding.as_u8());
}

test "new_with_padding allows a padding symbol that is not in the alphabet" {
    // '@' is printable and not present in the standard symbols.
    const a = try Alphabet.new_with_padding(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        .{ .s = '@' },
    );

    try testing.expectEqual(@as(u8, '@'), a.padding.as_u8());
}

test "new rejects length != 64" {
    try testing.expectError(error.InvalidLength, Alphabet.new("ABC"));
    try testing.expectError(error.InvalidLength, Alphabet.new(""));

    // 65 bytes.
    try testing.expectError(
        error.InvalidLength,
        Alphabet.new("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    );
}

test "new rejects duplicate at start" {
    try testing.expectError(
        error.DuplicatedByte,
        Alphabet.new("AACDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
    );
}

test "new rejects duplicate at end" {
    try testing.expectError(
        error.DuplicatedByte,
        Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789//"),
    );
}

test "new rejects duplicate in middle" {
    try testing.expectError(
        error.DuplicatedByte,
        Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZZbcdefghijklmnopqrstuvwxyz0123456789+/"),
    );
}

test "new rejects the reserved padding byte inside the alphabet" {
    try testing.expectError(
        error.ReservedByte,
        Alphabet.new("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+="),
    );
}

test "new_with_padding rejects a custom pad byte inside the alphabet" {
    // '@' is used as padding *and* present in the alphabet body.
    try testing.expectError(
        error.ReservedByte,
        Alphabet.new_with_padding(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+@",
            .{ .s = '@' },
        ),
    );
}

test "new rejects unprintable bytes" {
    // form feed (0x0c)
    try testing.expectError(
        error.UnprintableByte,
        Alphabet.new("\x0cBCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
    );

    // DEL (0x7f)
    try testing.expectError(
        error.UnprintableByte,
        Alphabet.new("\x7fBCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
    );

    // NUL (0x00)
    try testing.expectError(
        error.UnprintableByte,
        Alphabet.new("\x00BCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
    );
}

test "is_valid_b64_symbol accepts [32, 126] and nothing else" {
    try testing.expect(!is_valid_b64_symbol(0x00));
    try testing.expect(!is_valid_b64_symbol(0x1f)); // just below space
    try testing.expect(is_valid_b64_symbol(0x20)); // space
    try testing.expect(is_valid_b64_symbol(0x7e)); // tilde
    try testing.expect(!is_valid_b64_symbol(0x7f)); // DEL
    try testing.expect(!is_valid_b64_symbol(0x80));
    try testing.expect(!is_valid_b64_symbol(0xff));
}

test "Symbol.init rejects unprintable" {
    try testing.expect(Symbol.init(0x00) == null);
    try testing.expect(Symbol.init(0x1f) == null);
    try testing.expect(Symbol.init(0x7f) == null);
    try testing.expect(Symbol.init(0xff) == null);
}

test "Symbol.init accepts printable and preserves the byte" {
    try testing.expectEqual(@as(u8, 'A'), Symbol.init('A').?.as_u8());
    try testing.expectEqual(@as(u8, ' '), Symbol.init(' ').?.as_u8());
    try testing.expectEqual(@as(u8, '~'), Symbol.init('~').?.as_u8());
}

test "lookup table is complete and correct" {
    const a = try Alphabet.new(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    );

    // Every symbol maps back to its index.
    for (a.symbols, 0..) |sym, i| {
        try testing.expectEqual(@as(u8, @intCast(i)), a.lookup[sym]);
    }

    // Every byte NOT in the alphabet maps to 255.
    for (a.lookup, 0..) |idx, byte| {
        const present = std.mem.indexOfScalar(u8, &a.symbols, @intCast(byte)) != null;
        if (present) {
            try testing.expect(idx != 255);
        } else {
            try testing.expectEqual(@as(u8, 255), idx);
        }
    }
}

test "all provided constants have a valid lookup table and unique symbols" {
    const constants = [_]struct { name: []const u8, alphabet: Alphabet }{
        .{ .name = "STANDARD", .alphabet = STANDARD },
        .{ .name = "URL_SAFE", .alphabet = URL_SAFE },
        .{ .name = "CRYPT", .alphabet = CRYPT },
        .{ .name = "BCRYPT", .alphabet = BCRYPT },
        .{ .name = "IMAP_MUTF7", .alphabet = IMAP_MUTF7 },
        .{ .name = "BIN_HEX", .alphabet = BIN_HEX },
    };

    for (constants) |c| {
        // Every symbol maps back to its index.
        for (c.alphabet.symbols, 0..) |sym, i| {
            try testing.expectEqual(@as(u8, @intCast(i)), c.alphabet.lookup[sym]);
        }

        // Symbols are unique.
        for (c.alphabet.symbols, 0..) |sym, i| {
            for (c.alphabet.symbols[0..i]) |prev| {
                try testing.expect(sym != prev);
            }
        }

        // Non-alphabet bytes map to 255.
        for (c.alphabet.lookup, 0..) |idx, byte| {
            const present = std.mem.indexOfScalar(
                u8,
                &c.alphabet.symbols,
                @intCast(byte),
            ) != null;
            if (!present) try testing.expectEqual(@as(u8, 255), idx);
        }

        // All constants use '=' as padding.
        try testing.expectEqual(@as(u8, '='), c.alphabet.padding.as_u8());

        // Padding symbol is not in the alphabet body.
        try testing.expect(
            std.mem.indexOfScalar(u8, &c.alphabet.symbols, '=') == null,
        );
    }
}

test "URL_SAFE differs from STANDARD only at indices 62 and 63" {
    try testing.expectEqual(@as(u8, '+'), STANDARD.symbols[62]);
    try testing.expectEqual(@as(u8, '/'), STANDARD.symbols[63]);
    try testing.expectEqual(@as(u8, '-'), URL_SAFE.symbols[62]);
    try testing.expectEqual(@as(u8, '_'), URL_SAFE.symbols[63]);

    for (STANDARD.symbols[0..62], URL_SAFE.symbols[0..62]) |s, u| {
        try testing.expectEqual(s, u);
    }
}

test "IMAP_MUTF7 differs from STANDARD only at index 63" {
    try testing.expectEqual(@as(u8, '/'), STANDARD.symbols[63]);
    try testing.expectEqual(@as(u8, ','), IMAP_MUTF7.symbols[63]);

    for (STANDARD.symbols[0..63], IMAP_MUTF7.symbols[0..63]) |s, u| {
        try testing.expectEqual(s, u);
    }
}

test "CRYPT and BCRYPT share the './' prefix but order the rest differently" {
    try testing.expectEqualStrings("./", CRYPT.symbols[0..2]);
    try testing.expectEqualStrings("./", BCRYPT.symbols[0..2]);

    // CRYPT: 0-9A-Za-z after "./"
    try testing.expectEqual(@as(u8, '0'), CRYPT.symbols[2]);
    // BCRYPT: A-Za-z0-9 after "./"
    try testing.expectEqual(@as(u8, 'A'), BCRYPT.symbols[2]);
}
