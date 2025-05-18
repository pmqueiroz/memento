const std = @import("std");
const exception = @import("exception.zig");
const hash = @import("hash.zig");
const file = @import("file.zig");
const repository = @import("repository.zig");

pub fn Record() type {
    return struct {
        hash: [40]u8,
        mode: file.FileMode,
        len: usize,
        path: []const u8,
        const Self = @This();

        pub fn init(path: []const u8, f: std.fs.File) exception.MementoError!Self {
            const allocator = std.heap.page_allocator;

            const content = f.readToEndAlloc(allocator, 8192) catch {
                std.log.err("Error reading file: {s}\n", .{path});
                return exception.MementoError.UnableToReadFile;
            };
            defer allocator.free(content);

            const digest = try hash.sha1(.blob, content);

            try repository.createObject(&digest, content);

            const fileStat = f.stat() catch {
                std.log.err("Error getting file stat: {s}\n", .{path});
                return exception.MementoError.GenericError;
            };

            const mode = file.fileModeFromStat(fileStat);

            return .{
                .hash = digest,
                .mode = mode,
                .len = content.len,
                .path = path,
            };
        }

        pub fn initFromRaw(raw: []const u8) exception.MementoError!Self {
            var sequence = std.mem.splitSequence(u8, raw, " ");

            const rawHash = sequence.next() orelse return exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawMode = sequence.next() orelse return exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawLen = sequence.next() orelse return exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawPath = sequence.next() orelse return exception.MementoError.RawIsNotAnValidRecordEntry;

            var hashArr: [40]u8 = undefined;
            std.mem.copyForwards(u8, &hashArr, rawHash);

            const len = std.fmt.parseInt(usize, rawLen, 10) catch {
                std.log.err("Error parsing length: {s}\n", .{rawLen});
                return exception.MementoError.RawIsNotAnValidRecordEntry;
            };

            return .{
                .hash = hashArr,
                .mode = file.FileMode.fromString(rawMode),
                .len = len,
                .path = rawPath,
            };
        }

        pub fn allocateEntry(self: Self, allocator: std.mem.Allocator) exception.MementoError![]const u8 {
            const line = std.fmt.allocPrint(allocator, "{s} {s} {d} {s}\n", .{ self.hash, self.mode.toString(), self.len, self.path }) catch {
                return exception.MementoError.GenericError;
            };

            return line;
        }
    };
}
