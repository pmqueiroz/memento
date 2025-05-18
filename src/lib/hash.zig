const std = @import("std");
const objectType = @import("object-type.zig");
const exception = @import("exception.zig");

pub fn sha1(objType: objectType.ObjectType, content: []const u8) exception.MementoError![40]u8 {
    var header_buf: [64]u8 = undefined;
    const parsedObjType = objectType.toObjectTypeString(objType);

    const header_slice = std.fmt.bufPrint(
        &header_buf,
        "{s} {d}\x00",
        .{ parsedObjType, content.len },
    ) catch {
        return exception.MementoError.GenericError;
    };

    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update(header_slice);
    hasher.update(content);
    const result = hasher.finalResult();
    const hex: [40]u8 = std.fmt.bytesToHex(result, .lower);

    return hex;
}

test "it should generate a valid hash" {
    const content = "Hello, world!";
    const hash_result = try sha1(.blob, content);
    try std.testing.expectEqualStrings("5dd01c177f5d7d1be5346a5bc18a569a7410c2ef", &hash_result);
}
