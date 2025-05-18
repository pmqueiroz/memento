const std = @import("std");
const lib = @import("lib.zig");

pub fn Record() type {
    return struct {
        hash: [40]u8,
        mode: lib.file.FileMode,
        len: usize,
        path: []const u8,
        const Self = @This();

        pub fn init(path: []const u8, f: std.fs.File) lib.exception.MementoError!Self {
            const allocator = std.heap.page_allocator;

            const content = f.readToEndAlloc(allocator, 8192) catch {
                std.log.err("Error reading file: {s}\n", .{path});
                return lib.exception.MementoError.UnableToReadFile;
            };
            defer allocator.free(content);

            const hash = try lib.repository.createObject(.blob, content);

            const fileStat = f.stat() catch {
                std.log.err("Error getting file stat: {s}\n", .{path});
                return lib.exception.MementoError.GenericError;
            };

            const mode = lib.file.fileModeFromStat(fileStat);

            return .{
                .hash = hash,
                .mode = mode,
                .len = content.len,
                .path = path,
            };
        }

        pub fn initFromRaw(raw: []const u8) lib.exception.MementoError!Self {
            var sequence = std.mem.splitSequence(u8, raw, " ");

            const rawHash = sequence.next() orelse return lib.exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawMode = sequence.next() orelse return lib.exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawLen = sequence.next() orelse return lib.exception.MementoError.RawIsNotAnValidRecordEntry;
            const rawPath = sequence.next() orelse return lib.exception.MementoError.RawIsNotAnValidRecordEntry;

            var hashArr: [40]u8 = undefined;
            std.mem.copyForwards(u8, &hashArr, rawHash);

            const len = std.fmt.parseInt(usize, rawLen, 10) catch {
                std.log.err("Error parsing length: {s}\n", .{rawLen});
                return lib.exception.MementoError.RawIsNotAnValidRecordEntry;
            };

            return .{
                .hash = hashArr,
                .mode = lib.file.FileMode.fromString(rawMode),
                .len = len,
                .path = rawPath,
            };
        }

        pub fn allocateEntry(self: Self, allocator: std.mem.Allocator) lib.exception.MementoError![]const u8 {
            const line = std.fmt.allocPrint(allocator, "{s} {s} {d} {s}\n", .{ self.hash, self.mode.toString(), self.len, self.path }) catch {
                return lib.exception.MementoError.GenericError;
            };

            return line;
        }
    };
}
