const std = @import("std");
const exception = @import("exception.zig");

pub fn openRepository() exception.MementoError!std.fs.Dir {
    var dir = std.fs.cwd();
    while (true) {
        const repo = dir.openDir(".memento", .{ .iterate = true }) catch |err| {
            if (err == std.fs.Dir.OpenError.ProcessFdQuotaExceeded) {
                return exception.MementoError.NoRepositoryFound;
            }

            if (err == std.fs.Dir.OpenError.FileNotFound) {
                dir = dir.openDir("../", .{ .iterate = true }) catch |parentErr| {
                    if (parentErr == std.fs.Dir.OpenError.ProcessFdQuotaExceeded) {
                        return exception.MementoError.NoRepositoryFound;
                    }

                    if (parentErr == std.fs.Dir.OpenError.FileNotFound) {
                        return exception.MementoError.NoRepositoryFound;
                    }
                    return exception.MementoError.GenericError;
                };
                continue;
            }
            return exception.MementoError.GenericError;
        };
        return repo;
    }
}

pub fn createObject(hash: []const u8, content: []const u8) exception.MementoError!void {
    const allocator = std.heap.page_allocator;
    const repo = try openRepository();
    const bucket = hash[0..2];

    const object_path = std.fs.path.join(allocator, &.{ "objects", bucket, hash }) catch {
        return exception.MementoError.GenericError;
    };

    const object_dir = std.fs.path.dirname(object_path) orelse return exception.MementoError.GenericError;

    _ = repo.makePath(object_dir) catch {
        return exception.MementoError.CouldNotCreateFile;
    };
    defer allocator.free(object_path);

    const file = repo.createFile(object_path, .{}) catch {
        return exception.MementoError.CouldNotCreateFile;
    };

    defer file.close();

    file.writeAll(content) catch {
        return exception.MementoError.GenericError;
    };
}
