const std = @import("std");
const objectType = @import("object-type.zig");
const exception = @import("exception.zig");
const repository = @import("repository.zig");

pub fn sha1(payload: []const u8) exception.MementoError![40]u8 {
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(payload);
    const result = hasher.finalResult();
    const hash: [40]u8 = std.fmt.bytesToHex(result, .lower);

    return hash;
}

test "it should generate a valid hash" {
    const content = "Hello, world!";
    const hash_result = try sha1(.blob, content);
    try std.testing.expectEqualStrings("5dd01c177f5d7d1be5346a5bc18a569a7410c2ef", &hash_result);
}
