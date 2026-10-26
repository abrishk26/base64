# base64

A Base64 encoding and decoding library for Zig.

## Requirements

Zig 0.17.0 or later.

## Usage

Add the dependency to your project:

```
zig fetch --save https://github.com/abrishk26/base64/archive/refs/heads/main.tar.gz
```

Wire it up in `build.zig`:

```zig
const base64 = b.dependency("base64", .{});
exe.root_module.addImport("base64", base64.module("base64"));
```

## Examples

### Encoding

```zig
const base64 = @import("base64");

const engine = base64.Engine.init(.{});

const encoded = try engine.encode(allocator, "foobar");
defer allocator.free(encoded);
// encoded == "Zm9vYmFy"
```

### Decoding

Both padded and unpadded input are accepted.

```zig
const base64 = @import("base64");

const engine = base64.Engine.init(.{});

const decoded = try engine.decode(allocator, "Zm9vYmFy");
defer allocator.free(decoded);
// decoded == "foobar"

const decoded_unpadded = try engine.decode(allocator, "Zg");
defer allocator.free(decoded_unpadded);
// decoded_unpadded == "f"
```

### URL-safe alphabet (RFC 4648)

Uses `-` and `_` instead of `+` and `/`, safe for use in URLs and filenames.

```zig
const base64 = @import("base64");

const engine = base64.Engine.init(.{ .alphabet = base64.alphabet.URL_SAFE });

const encoded = try engine.encode(allocator, &[_]u8{ 0xfb, 0xef, 0xbe });
defer allocator.free(encoded);
// encoded == "----"
```

### IMAP modified UTF-7

```zig
const base64 = @import("base64");

const engine = base64.Engine.init(.{ .alphabet = base64.alphabet.IMAP_MUTF7 });

const encoded = try engine.encode(allocator, &[_]u8{ 0xff, 0xff, 0xff });
defer allocator.free(encoded);
// encoded == ",,,,"
```

### Custom alphabet

```zig
const base64 = @import("base64");

const custom = try base64.alphabet.Alphabet.new(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
);
const engine = base64.Engine.init(.{ .alphabet = custom });

const encoded = try engine.encode(allocator, "foobar");
defer allocator.free(encoded);
// encoded == "Zm9vYmFy"

const decoded = try engine.decode(allocator, "Zm9vYmFy");
defer allocator.free(decoded);
// decoded == "foobar"
```

Custom padding symbol:

```zig
const custom = try base64.alphabet.Alphabet.new_with_padding(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    '@',
);
const engine = base64.Engine.init(.{ .alphabet = custom });

const encoded = try engine.encode(allocator, "f");
defer allocator.free(encoded);
// encoded == "Zg@@"

const decoded = try engine.decode(allocator, "Zg@@");
defer allocator.free(decoded);
// decoded == "f"
```

## Built-in alphabets

| Constant                    | Description                        |
|-----------------------------|------------------------------------|
| `alphabet.STANDARD`         | RFC 4648 section 4, uses `+` and `/`  |
| `alphabet.URL_SAFE`         | RFC 4648 section 5, uses `-` and `_`  |
| `alphabet.CRYPT`            | crypt(3)                           |
| `alphabet.BCRYPT`           | bcrypt                             |
| `alphabet.IMAP_MUTF7`       | IMAP modified UTF-7, uses `+` and `,` |
| `alphabet.BIN_HEX`          | BinHex 4.0                         |

## Errors

### Encoding

| Error        | Cause                                                         |
|--------------|---------------------------------------------------------------|
| `Overflow`   | Input is so large the output length overflows `usize`.        |
| `OutOfMemory`| Allocator failed.                                             |

### Decoding

| Error             | Cause                                                    |
|-------------------|----------------------------------------------------------|
| `InvalidCharacter`| Input contains a byte not present in the alphabet.       |
| `InvalidLength`   | Unpadded input length is `4k + 1`, which is never valid. |
| `InvalidPadding`  | Too many `=` symbols, `=` appears before the end, or padded input length is not a multiple of 4. |
| `Overflow`        | Input is so large the output length overflows `usize`.   |
| `OutOfMemory`     | Allocator failed.                                        |

### Alphabet construction

| Error           | Cause                                              |
|-----------------|----------------------------------------------------|
| `InvalidLength` | Alphabet string is not exactly 64 bytes.           |
| `DuplicatedByte`| Alphabet contains a repeated byte.                 |
| `UnprintableByte`| Alphabet contains a byte outside `[32, 126]`.     |
| `ReservedByte`  | The padding symbol appears in the alphabet body.   |
