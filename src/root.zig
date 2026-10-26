const std = @import("std");
const alphabet = @import("alphabet.zig");
const errors = @import("errors.zig");

pub const EncodeError = errors.EncodeError;
pub const DecodeError = errors.DecodeError;

pub const EngineConfig = struct { alphabet: alphabet.Alphabet = alphabet.STANDARD };

pub const Engine = struct {
    alphabet: alphabet.Alphabet,

    pub fn init(
        config: EngineConfig,
    ) Engine {
        return .{ .alphabet = config.alphabet };
    }

    pub fn encode(self: Engine, allocator: std.mem.Allocator, input: []const u8) EncodeError!std.ArrayList(u8) {
        const symbols = self.alphabet.symbols;
        const padding = self.alphabet.padding;

        var buf = [_]u8{ 0, 0, 0 };
        var output = try std.ArrayList(u8).initCapacity(allocator, try _calc_encode_len(input.len));
        errdefer output.deinit(allocator);

        var count: usize = 0;
        for (input) |byte| {
            buf[count] = byte;
            count += 1;

            if (count == 3) {
                try output.appendSlice(allocator, &.{ symbols[buf[0] >> 2], symbols[((buf[0] & 3) << 4) | (buf[1] >> 4)], symbols[((buf[1] & 15) << 2) | (buf[2] >> 6)], symbols[buf[2] & 63] });
                count = 0;
            }
        }

        if (count == 1) {
            try output.appendSlice(allocator, &.{ symbols[buf[0] >> 2], symbols[(buf[0] & 3) << 4], padding.as_u8(), padding.as_u8() });
        }

        if (count == 2) {
            try output.appendSlice(allocator, &.{ symbols[buf[0] >> 2], symbols[((buf[0] & 3) << 4) | (buf[1] >> 4)], symbols[(buf[1] & 15) << 2], padding.as_u8() });
        }

        return output;
    }

    pub fn decode(
        self: Engine,
        allocator: std.mem.Allocator,
        input: []const u8,
    ) DecodeError!std.ArrayList(u8) {
        const pad = self.alphabet.padding.as_u8();

        // Count *trailing* padding only.
        var pad_count: usize = 0;
        while (pad_count < input.len and input[input.len - 1 - pad_count] == pad) {
            pad_count += 1;
        }

        if (pad_count > 2) return error.InvalidPadding;
        if (pad_count > 0 and input.len % 4 != 0) return error.InvalidPadding;
        if (pad_count == 0 and input.len % 4 == 1) return error.InvalidLength;

        const data = input[0 .. input.len - pad_count];

        // Any remaining pad symbol in the data portion is misplaced.
        if (std.mem.indexOfScalar(u8, data, pad) != null) return error.InvalidPadding;

        var buf: [4]u8 = undefined;
        var count: usize = 0;

        var output = try std.ArrayList(u8).initCapacity(
            allocator,
            try _calc_decode_len(input.len, pad_count),
        );
        errdefer output.deinit(allocator);

        for (data) |byte| {
            buf[count] = try self._char_index(byte);
            count += 1;

            if (count == 4) {
                try output.appendSlice(allocator, &.{
                    (buf[0] << 2) | (buf[1] >> 4),
                    (buf[1] << 4) | (buf[2] >> 2),
                    (buf[2] << 6) | buf[3],
                });
                count = 0;
            }
        }

        switch (count) {
            0 => {},
            2 => try output.append(allocator, (buf[0] << 2) | (buf[1] >> 4)),
            3 => try output.appendSlice(allocator, &.{
                (buf[0] << 2) | (buf[1] >> 4),
                (buf[1] << 4) | (buf[2] >> 2),
            }),
            else => return error.InvalidLength,
        }

        return output;
    }

    // we have 64 chars and how do we perform reverse look up based on their ascii values
    fn _char_index(self: Engine, char: u8) error{InvalidCharacter}!u8 {
        const index = self.alphabet.lookup[char];
        if (index == 255) return error.InvalidCharacter;
        return index;
    }
};

fn _calc_encode_len(input_len: usize) error{Overflow}!usize {
    const groups = input_len / 3 + @intFromBool(input_len % 3 != 0);
    return std.math.mul(usize, groups, 4) catch error.Overflow;
}

fn _calc_decode_len(
    input_len: usize,
    padding_length: usize,
) error{Overflow}!usize {
    if (padding_length > input_len) return error.Overflow;

    const symbols = input_len - padding_length;
    return (try std.math.mul(usize, symbols, 3)) / 4;
}

const testing = std.testing;

fn expectEncode(
    engine: Engine,
    input: []const u8,
    expected: []const u8,
) !void {
    var out = try engine.encode(testing.allocator, input);
    defer out.deinit(testing.allocator);

    try testing.expectEqualSlices(u8, expected, out.items);
    try testing.expectEqual(expected.len, out.items.len);
}

fn expectDecode(
    engine: Engine,
    input: []const u8,
    expected: []const u8,
) !void {
    var out = try engine.decode(testing.allocator, input);
    defer out.deinit(testing.allocator);

    try testing.expectEqualSlices(u8, expected, out.items);
    try testing.expectEqual(expected.len, out.items.len);
}

const Rfc4648Vector = struct {
    decoded: []const u8,
    encoded: []const u8,
};

const rfc4648_vectors = [_]Rfc4648Vector{
    .{ .decoded = "", .encoded = "" },
    .{ .decoded = "f", .encoded = "Zg==" },
    .{ .decoded = "fo", .encoded = "Zm8=" },
    .{ .decoded = "foo", .encoded = "Zm9v" },
    .{ .decoded = "foob", .encoded = "Zm9vYg==" },
    .{ .decoded = "fooba", .encoded = "Zm9vYmE=" },
    .{ .decoded = "foobar", .encoded = "Zm9vYmFy" },
};

test "RFC 4648 §10: encode" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    for (rfc4648_vectors) |v| {
        try expectEncode(engine, v.decoded, v.encoded);
    }
}

test "RFC 4648 §10: decode" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    for (rfc4648_vectors) |v| {
        try expectDecode(engine, v.encoded, v.decoded);
    }
}

test "RFC 4648 §10: roundtrip" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    for (rfc4648_vectors) |v| {
        var encoded = try engine.encode(testing.allocator, v.decoded);
        defer encoded.deinit(testing.allocator);

        var decoded = try engine.decode(testing.allocator, encoded.items);
        defer decoded.deinit(testing.allocator);

        try testing.expectEqualSlices(u8, v.decoded, decoded.items);
    }
}

test "decode accepts unpadded input" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try expectDecode(engine, "Zg", "f");
    try expectDecode(engine, "Zm8", "fo");
    try expectDecode(engine, "Zm9v", "foo");
    try expectDecode(engine, "Zm9vYg", "foob");
}

test "decode rejects characters outside the alphabet" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "!!!!"),
    );

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "Zm9-"),
    );

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "Zm9_"),
    );
}

test "decode rejects invalid characters in unpadded input" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "Zg!"),
    );
}

test "decode rejects more than two padding symbols" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidPadding,
        engine.decode(testing.allocator, "Zg==="),
    );

    try testing.expectError(
        error.InvalidPadding,
        engine.decode(testing.allocator, "===="),
    );
}

test "decode rejects padding in non-final position" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidPadding,
        engine.decode(testing.allocator, "Zg==Zg=="),
    );

    try testing.expectError(
        error.InvalidPadding,
        engine.decode(testing.allocator, "Z=g="),
    );
}

test "decode rejects padded input whose length is not a multiple of 4" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidPadding,
        engine.decode(testing.allocator, "Zg="),
    );
}

test "decode accepts padded input whose length is a multiple of 4" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try expectDecode(engine, "Zg==", "f");
    try expectDecode(engine, "Zm9vYg==", "foob");
}

test "decode rejects unpadded input of length 4k + 1" {
    const engine = Engine.init(.{ .alphabet = alphabet.STANDARD });

    try testing.expectError(
        error.InvalidLength,
        engine.decode(testing.allocator, "Z"),
    );

    try testing.expectError(
        error.InvalidLength,
        engine.decode(testing.allocator, "Zm9vZ"),
    );

    try testing.expectError(
        error.InvalidLength,
        engine.decode(testing.allocator, "Zm9vZm9vZ"),
    );
}

test "URL_SAFE alphabet roundtrip" {
    const engine = Engine.init(.{ .alphabet = alphabet.URL_SAFE });

    // Characters common to both alphabets produce the same encoding.
    try expectEncode(engine, "foobar", "Zm9vYmFy");

    // 0xfb 0xef 0xbe -> "++++" in STANDARD and "----" in URL_SAFE.
    const bytes = [_]u8{ 0xfb, 0xef, 0xbe };

    try expectEncode(engine, &bytes, "----");
    try expectDecode(engine, "----", &bytes);
}

test "URL_SAFE encodes index 63 as underscore" {
    const engine = Engine.init(.{ .alphabet = alphabet.URL_SAFE });
    const bytes = [_]u8{ 0xff, 0xff, 0xff };

    try expectEncode(engine, &bytes, "____");
    try expectDecode(engine, "____", &bytes);
}

test "URL_SAFE decodes '-' and '_' but rejects '+' and '/'" {
    const engine = Engine.init(.{ .alphabet = alphabet.URL_SAFE });

    try expectDecode(engine, "----", &[_]u8{ 0xfb, 0xef, 0xbe });
    try expectDecode(engine, "____", &[_]u8{ 0xff, 0xff, 0xff });

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "+/++"),
    );
}

test "IMAP_MUTF7 uses ',' instead of '/'" {
    const engine = Engine.init(.{ .alphabet = alphabet.IMAP_MUTF7 });

    const bytes = [_]u8{ 0xfb, 0xef, 0xbe };

    // All four Base64 indices are 62, which maps to '+'.
    try expectEncode(engine, &bytes, "++++");
    try expectDecode(engine, "++++", &bytes);

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "+/++"),
    );
}

test "IMAP_MUTF7 encodes index 63 as comma" {
    const engine = Engine.init(.{ .alphabet = alphabet.IMAP_MUTF7 });
    const bytes = [_]u8{ 0xff, 0xff, 0xff };

    try expectEncode(engine, &bytes, ",,,,");
    try expectDecode(engine, ",,,,", &bytes);
}

test "custom padding symbol is honoured" {
    const custom_alphabet = try alphabet.Alphabet.new_with_padding(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
        .{ .s = '@' },
    );

    const engine = Engine.init(.{ .alphabet = custom_alphabet });

    try expectEncode(engine, "f", "Zg@@");
    try expectDecode(engine, "Zg@@", "f");

    try testing.expectError(
        error.InvalidCharacter,
        engine.decode(testing.allocator, "Zg=="),
    );
}

test "calc_encode_len" {
    // ceil(input_len / 3) * 4
    try testing.expectEqual(@as(usize, 0), try _calc_encode_len(0));
    try testing.expectEqual(@as(usize, 4), try _calc_encode_len(1));
    try testing.expectEqual(@as(usize, 4), try _calc_encode_len(2));
    try testing.expectEqual(@as(usize, 4), try _calc_encode_len(3));
    try testing.expectEqual(@as(usize, 8), try _calc_encode_len(4));
    try testing.expectEqual(@as(usize, 8), try _calc_encode_len(5));
    try testing.expectEqual(@as(usize, 8), try _calc_encode_len(6));
    try testing.expectEqual(@as(usize, 12), try _calc_encode_len(7));
}

test "calc_decode_len" {
    // floor((input_len - padding_length) * 3 / 4)
    try testing.expectEqual(@as(usize, 0), try _calc_decode_len(0, 0));
    try testing.expectEqual(@as(usize, 1), try _calc_decode_len(2, 0));
    try testing.expectEqual(@as(usize, 2), try _calc_decode_len(3, 0));
    try testing.expectEqual(@as(usize, 3), try _calc_decode_len(4, 0));
    try testing.expectEqual(@as(usize, 4), try _calc_decode_len(6, 0));
    try testing.expectEqual(@as(usize, 5), try _calc_decode_len(7, 0));
    try testing.expectEqual(@as(usize, 6), try _calc_decode_len(8, 0));

    // Padding is excluded from the symbol count.
    try testing.expectEqual(@as(usize, 1), try _calc_decode_len(4, 2));
    try testing.expectEqual(@as(usize, 2), try _calc_decode_len(4, 1));
    try testing.expectEqual(@as(usize, 4), try _calc_decode_len(8, 2));

    // Invalid arguments must not underflow.
    try testing.expectError(
        error.Overflow,
        _calc_decode_len(3, 4),
    );
}
