const std = @import("std");
const lib = @import("../../lib/lib.zig");

pub fn indexFile(path: []const u8) lib.exception.MementoError![]const u8 {
    const allocator = std.heap.page_allocator;

    const file = std.fs.cwd().openFile(path, .{}) catch {
        std.log.err("File not found: {s}\n", .{path});
        return lib.exception.MementoError.FileNotFound;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 8192) catch {
        std.log.err("Error reading file: {s}\n", .{path});
        return lib.exception.MementoError.UnableToReadFile;
    };

    const hash = try lib.hash.sha1(.blob, content);
    try lib.repository.createObject(&hash, content);

    const fileStat = file.stat() catch {
        std.log.err("Error getting file stat: {s}\n", .{path});
        return lib.exception.MementoError.GenericError;
    };

    const mode = lib.file.fileModeFromStat(fileStat);
    const line = std.fmt.allocPrint(std.heap.page_allocator, "{s} {s} {d} {s}\n", .{ hash, mode.toString(), content.len, path }) catch {
        return lib.exception.MementoError.GenericError;
    };

    return line;
}
