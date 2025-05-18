const std = @import("std");
const lib = @import("lib.zig");

pub fn zlib(
    allocator: std.mem.Allocator,
    payload: []const u8,
) lib.exception.MementoError![]u8 {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    var stream = std.io.fixedBufferStream(payload);
    std.compress.zlib.compress(stream.reader(), output.writer(), .{}) catch {
        return lib.exception.MementoError.GenericError;
    };

    return output.toOwnedSlice() catch {
        return lib.exception.MementoError.GenericError;
    };
}
