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

    const indexFile = repo.openFile("index", .{}) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer indexFile.close();
    const buf = indexFile.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer allocator.free(buf);
    var indexFileIterator = std.mem.splitScalar(u8, buf, '\n');

    var dedupedEntries = std.ArrayList([]const u8).init(allocator);
    defer dedupedEntries.deinit();

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

        while (indexFileIterator.next()) |rawEntry| {
            if (rawEntry.len == 0) continue;
            const lineEntry = try lib.Record().initFromRaw(rawEntry);
            if (!std.mem.eql(u8, lineEntry.path, record.path)) {
                dedupedEntries.append(rawEntry) catch {
                    std.debug.print("Error appending line: {s}\n", .{rawEntry});
                    return lib.exception.MementoError.GenericError;
                };
            }
        }

        indexFileIterator.reset();

        dedupedEntries.append(entry) catch {
            std.debug.print("Error appending entry: {s}\n", .{entry});
            return lib.exception.MementoError.GenericError;
        };
    }

    var idx_file = repo.createFile("index", .{ .truncate = false }) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer idx_file.close();
    for (dedupedEntries.items, 0..) |rawEntry, i| {
        idx_file.writeAll(rawEntry) catch {
            return lib.exception.MementoError.GenericError;
        };
        if (i < dedupedEntries.items.len - 1) {
            idx_file.writeAll("\n") catch {
                return lib.exception.MementoError.GenericError;
            };
        }
    }
}
