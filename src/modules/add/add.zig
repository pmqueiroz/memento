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

    var lines = std.ArrayList([]const u8).init(allocator);
    const indexFile = repo.openFile("index", .{}) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer indexFile.close();
    var buf_reader = std.io.bufferedReader(indexFile.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();
    const writer = line.writer();
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        if (line.items.len == 0) {
            continue;
        }

        lines.append(line.items) catch {
            std.debug.print("Error appending line: {s}\n", .{line.items});
            return lib.exception.MementoError.GenericError;
        };
    } else |err| switch (err) {
        error.EndOfStream => {
            if (line.items.len > 0) {
                std.debug.print("end: {s}\n", .{line.items});
            }
        },
        else => return lib.exception.MementoError.GenericError,
    }

    for (config.files_to_add) |path| {
        std.fs.cwd().access(path, .{}) catch |err| {
            if (err == std.posix.AccessError.FileNotFound) {
                std.log.err("File not found: {s}\n", .{path});
                return lib.exception.MementoError.FileNotFound;
            }
            return lib.exception.MementoError.GenericError;
        };

        const file = std.fs.cwd().openFile(path, .{}) catch {
            std.log.err("File not found: {s}\n", .{path});
            return lib.exception.MementoError.FileNotFound;
        };
        defer file.close();

        const record = try lib.Record().init(path, file);
        const entry = try record.allocateEntry(allocator);

        var cleaned = std.ArrayList([]const u8).init(allocator);
        for (lines.items) |rawEntry| {
            const lineEntry = try lib.Record().initFromRaw(rawEntry);
            if (!std.mem.eql(u8, lineEntry.path, lineEntry.path)) {
                cleaned.append(rawEntry) catch {
                    std.debug.print("Error appending line: {s}\n", .{rawEntry});
                    return lib.exception.MementoError.GenericError;
                };
            }
        }
        cleaned.append(entry) catch {
            std.debug.print("Error appending entry: {s}\n", .{entry});
            return lib.exception.MementoError.GenericError;
        };
        lines = cleaned;
    }

    var idx_file = repo.createFile("index", .{ .truncate = true }) catch {
        return lib.exception.MementoError.GenericError;
    };
    defer idx_file.close();
    for (lines.items) |rawEntry| {
        idx_file.writeAll(rawEntry) catch {
            return lib.exception.MementoError.GenericError;
        };
    }
}
