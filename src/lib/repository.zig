const std = @import("std");
const lib = @import("lib.zig");

pub fn openRepository() lib.exception.MementoError!std.fs.Dir {
    var dir = std.fs.cwd();
    while (true) {
        const repo = dir.openDir(".memento", .{ .iterate = true }) catch |err| {
            if (err == std.fs.Dir.OpenError.ProcessFdQuotaExceeded) {
                return lib.exception.MementoError.NoRepositoryFound;
            }

            if (err == std.fs.Dir.OpenError.FileNotFound) {
                dir = dir.openDir("../", .{ .iterate = true }) catch |parentErr| {
                    if (parentErr == std.fs.Dir.OpenError.ProcessFdQuotaExceeded) {
                        return lib.exception.MementoError.NoRepositoryFound;
                    }

                    if (parentErr == std.fs.Dir.OpenError.FileNotFound) {
                        return lib.exception.MementoError.NoRepositoryFound;
                    }
                    return lib.exception.MementoError.GenericError;
                };
                continue;
            }
            return lib.exception.MementoError.GenericError;
        };
        return repo;
    }
}

pub fn createObject(objType: lib.objectType.ObjectType, content: []const u8) lib.exception.MementoError![40]u8 {
    const allocator = std.heap.page_allocator;
    const repo = try openRepository();
    const parsedObjType = lib.objectType.toObjectTypeString(objType);
    const payload = std.fmt.allocPrint(
        allocator,
        "{s} {d}\x00{s}",
        .{ parsedObjType, content.len, content },
    ) catch {
        return lib.exception.MementoError.GenericError;
    };
    defer allocator.free(payload);
    const digest = try lib.hash.sha1(payload);

    const object_path = std.fs.path.join(allocator, &.{ "objects", digest[0..2], digest[2..] }) catch {
        return lib.exception.MementoError.GenericError;
    };

    const object_dir = std.fs.path.dirname(object_path) orelse return lib.exception.MementoError.GenericError;

    _ = repo.makePath(object_dir) catch {
        return lib.exception.MementoError.CouldNotCreateFile;
    };
    defer allocator.free(object_path);

    const file = repo.createFile(object_path, .{}) catch {
        return lib.exception.MementoError.CouldNotCreateFile;
    };

    defer file.close();

    const compressedPayload = try lib.compress.zlib(allocator, payload);
    defer allocator.free(compressedPayload);

    file.writeAll(compressedPayload) catch {
        return lib.exception.MementoError.GenericError;
    };

    return digest;
}
