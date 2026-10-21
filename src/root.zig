const std = @import("std");

pub const EngineConfig = struct { 
    alphabet: [64]u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".*, 
    padding: u8 = '=' 
};

pub const Engine = struct {
    alphabet: [64]u8,
    padding: u8,

    pub fn init(
        conf: EngineConfig,
    ) Engine {
        return .{ 
            .alphabet = conf.alphabet, 
            .padding = conf.padding 
        };
    }

    pub fn encode(self: Engine, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var buf = [_]u8{ 0, 0, 0 };
        var output = try std.ArrayList(u8).initCapacity(allocator, try calc_encode_len(input.len));

        var count: usize = 0;
        for (input) |byte| {
            buf[count] = byte;
            count += 1;

            if (count == 3) {
                try output.appendSlice(allocator, &.{
                    self.alphabet[buf[0] >> 2],
                    self.alphabet[((buf[0] & 3) << 4) | (buf[1] >> 4)],
                    self.alphabet[((buf[1] & 15) << 2) | (buf[2] >> 6)],
                    self.alphabet[buf[2] & 63]
                });
                count = 0;
            }
        }

        if (count == 1) {
            try output.appendSlice(allocator, &.{
                self.alphabet[buf[0] >> 2],
                self.alphabet[(buf[0] & 3) << 4],
                self.padding,
                self.padding 
            });
        }

        if (count == 2) {
            try output.appendSlice(allocator, &.{
                self.alphabet[buf[0] >> 2],
                self.alphabet[((buf[0] & 3) << 4) | (buf[1] >> 4)],
                self.alphabet[(buf[1] & 15) << 2],
                self.padding 
            });
        }

        return output.items;
    }

    pub fn calc_encode_len(input_len: usize) !usize {
        return (if (input_len < 3) 4 else try std.math.divCeil(usize, input_len, 3)) * 4;
    }

    pub fn calc_decode_len(input_len: usize) !usize {
        return (if (input_len < 4) 3 else try std.math.divFloor(usize, input_len, 4)) * 3;
    }
};
