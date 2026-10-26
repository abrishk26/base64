//! Error types shared across the base64 library.

const std = @import("std");

/// Errors that can occur while encoding.
pub const EncodeError = std.mem.Allocator.Error || error{
    /// The calculated output length would overflow `usize`.
    /// Only reachable for inputs larger than `3 * usize.max / 4`.
    Overflow,
};

/// Errors that can occur while decoding.
pub const DecodeError = std.mem.Allocator.Error || error{
    /// The input contains a byte that is not part of the alphabet.
    /// This includes bytes with no reverse-lookup entry (the `255` sentinel).
    InvalidCharacter,

    /// The input length is inconsistent with base64 framing.
    /// In particular, unpadded input of length `4k + 1`.
    InvalidLength,

    /// Padding is invalid: too many `=` symbols, `=` appears before the end,
    /// or padded input whose length is not a multiple of 4.
    InvalidPadding,

    /// The calculated output length would overflow `usize`.
    Overflow,
};

/// Returns a short, stable description of an error, for logging.
/// Unlike `@errorName`, this is safe to change wording on.
pub fn describe(err: anyerror) []const u8 {
    return switch (err) {
        error.OutOfMemory     => "out of memory",
        error.Overflow        => "length overflow",
        error.InvalidCharacter => "invalid character in input",
        error.InvalidLength   => "invalid input length",
        error.InvalidPadding  => "invalid padding",
        else                  => @errorName(err),
    };
}