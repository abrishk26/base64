const std = @import("std");

pub const EngineConfig = struct { alphabet: [64]u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".*, padding: u8 = '=' };

pub const Engine = struct {
    alphabet: [64]u8,
    padding: u8,

    pub fn init(
        config: EngineConfig,
    ) Engine {
        return .{ .alphabet = config.alphabet, .padding = config.padding };
    }

    pub fn encode(self: Engine, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var buf = [_]u8{ 0, 0, 0 };
        var output = try std.ArrayList(u8).initCapacity(allocator, try calc_encode_len(input.len));

        var count: usize = 0;
        for (input) |byte| {
            buf[count] = byte;
            count += 1;

            if (count == 3) {
                try output.appendSlice(allocator, &.{ self.alphabet[buf[0] >> 2], self.alphabet[((buf[0] & 3) << 4) | (buf[1] >> 4)], self.alphabet[((buf[1] & 15) << 2) | (buf[2] >> 6)], self.alphabet[buf[2] & 63] });
                count = 0;
            }
        }

        if (count == 1) {
            try output.appendSlice(allocator, &.{ self.alphabet[buf[0] >> 2], self.alphabet[(buf[0] & 3) << 4], self.padding, self.padding });
        }

        if (count == 2) {
            try output.appendSlice(allocator, &.{ self.alphabet[buf[0] >> 2], self.alphabet[((buf[0] & 3) << 4) | (buf[1] >> 4)], self.alphabet[(buf[1] & 15) << 2], self.padding });
        }

        return output.items;
    }
    pub fn decode(self: Engine, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var buf = [_]u8{ 0, 0, 0, 0 };
        const padding_count = std.mem.count(u8, input, &.{self.padding});
        var output = try std.ArrayList(u8).initCapacity(allocator, try calc_decode_len(input.len, padding_count));
        var count: usize = 0;

        for (input[0..(input.len - padding_count)]) |byte| {
            buf[count] = self._char_index(byte);
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
        
        try output.appendSlice(allocator, switch (count) {
            3 => &.{
                (buf[0] << 2) | (buf[1] >> 4),
                (buf[1] << 4) | (buf[2] >> 2),
            },
            2 => &.{
                (buf[0] << 2) | (buf[1] >> 4),
            },
            else => return output.items,
        });

        return output.items;
    }

    pub fn _count_padding(input: []const u8, padding: u8) usize {
        var count: usize = 0;
        for (input) |byte| {
            if (byte == padding) count += 1;
        }

        return count;
    }

    pub fn _char_at(self: Engine, index: usize) u8 {
        return self.alphabet[index];
    }

    fn _char_index(self: Engine, char: u8) u8 {
        if (char == '=')
            return 64;

        var i: u8 = 0;
        var output_index: u8 = 0;

        while (i < 64) : (i += 1) {
            if (self._char_at(i) == char)
                break;
            output_index += 1;
        }

        return output_index;
    }

    pub fn calc_encode_len(input_len: usize) !usize {
        return (if (input_len < 3) 4 else try std.math.divCeil(usize, input_len, 3)) * 4;
    }

    pub fn calc_decode_len(input_len: usize, padding_length: usize) !usize {
        return (if ((input_len < 4)) 3 else (try std.math.divFloor(usize, input_len, 4)) * 3) - padding_length;
    }
};
