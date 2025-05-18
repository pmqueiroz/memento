const std = @import("std");
const index = @import("index.zig");
const lib = @import("../../lib/lib.zig");
const config = @import("../../config.zig");

pub fn runAdd() lib.exception.MementoError!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (config.files_to_add.len == 0) {
        return lib.exception.MementoError.NoFilesToIndex;
    }

    const repo = try lib.repository.openRepository();

    var index_buf: []u8 = undefined;
    if (repo.openFile("index", .{}) catch null) |f| {
        index_buf = f.readToEndAlloc(allocator, 4096) catch {
            return lib.exception.MementoError.GenericError;
        };
    } else {
        index_buf = &[_]u8{};
    }

    var out_index = std.ArrayList(u8).init(allocator);
    out_index.appendSlice(index_buf) catch {
        return lib.exception.MementoError.GenericError;
    };

    for (config.files_to_add) |file| {
        std.fs.cwd().access(file, .{}) catch |err| {
            if (err == std.posix.AccessError.FileNotFound) {
                std.log.err("File not found: {s}\n", .{file});
                return lib.exception.MementoError.FileNotFound;
            }
            return lib.exception.MementoError.GenericError;
        };

        const record = try lib.Record().init(allocator, file);
        defer record.deinit();
        try record.createObject();
        const entry = try record.allocateEntry(allocator);

        out_index.appendSlice(entry) catch {
            return lib.exception.MementoError.GenericError;
        };
    }

    var idx_file = repo.createFile("index", .{ .truncate = true }) catch {
        return lib.exception.MementoError.GenericError;
    };
    defer idx_file.close();
    idx_file.writeAll(out_index.items) catch {
        return lib.exception.MementoError.GenericError;
    };
}

test "it should return NoFilesToIndex if no files are provided" {
    const result = runAdd();
    try std.testing.expectError(lib.exception.MementoError.NoFilesToIndex, result);
}
