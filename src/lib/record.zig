const std = @import("std");
const exception = @import("exception.zig");
const hash = @import("hash.zig");
const file = @import("file.zig");
const repository = @import("repository.zig");

pub fn Record() type {
    return struct {
        content: []const u8,
        hash: [40]u8,
        mode: file.FileMode,
        allocator: std.mem.Allocator,
        path: []const u8,
        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, path: []const u8) exception.MementoError!Self {
            const f = std.fs.cwd().openFile(path, .{}) catch {
                std.log.err("File not found: {s}\n", .{path});
                return exception.MementoError.FileNotFound;
            };
            defer f.close();

            const content = f.readToEndAlloc(allocator, 8192) catch {
                std.log.err("Error reading file: {s}\n", .{path});
                return exception.MementoError.UnableToReadFile;
            };

            const digest = try hash.sha1(.blob, content);

            const fileStat = f.stat() catch {
                std.log.err("Error getting file stat: {s}\n", .{path});
                return exception.MementoError.GenericError;
            };

            const mode = file.fileModeFromStat(fileStat);

            return .{
                .content = content,
                .hash = digest,
                .mode = mode,
                .allocator = allocator,
                .path = path,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.content);
        }

        pub fn createObject(self: Self) exception.MementoError!void {
            try repository.createObject(&self.hash, self.content);
        }

        pub fn allocateEntry(self: Self, allocator: std.mem.Allocator) exception.MementoError![]const u8 {
            const line = std.fmt.allocPrint(allocator, "{s} {s} {d} {s}\n", .{ self.hash, self.mode.toString(), self.content.len, self.path }) catch {
                return exception.MementoError.GenericError;
            };

            return line;
        }
    };
}
