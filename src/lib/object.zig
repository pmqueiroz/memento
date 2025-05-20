const std = @import("std");
const lib = @import("lib.zig");

pub const Author = struct {
    name: []const u8,
    email: []const u8,
};

pub const TreeEntry = struct {
    mode: []const u8,
    name: []const u8,
    hash: [40]u8,
};

pub const ObjectType = enum {
    blob,
    tree,
    commit,
};

fn toObjectTypeString(objType: ObjectType) []const u8 {
    const result = switch (objType) {
        .blob => "blob",
        .commit => "commit",
        .tree => "tree",
    };
    return result;
}

pub fn createBlob(content: []const u8) lib.exception.MementoError![40]u8 {
    const allocator = std.heap.page_allocator;
    return try createObject(allocator, .blob, content);
}

pub fn createTree(entries: []TreeEntry) lib.exception.MementoError![40]u8 {
    const allocator = std.heap.page_allocator;

    var result = std.ArrayList([]const u8).init(allocator);
    defer result.deinit();

    for (entries) |value| {
        const entry = std.fmt.allocPrint(
            allocator,
            "{s} {s}\x00{s}",
            .{ value.mode, value.name, value.hash },
        ) catch {
            return lib.exception.MementoError.GenericError;
        };
        defer allocator.free(entry);

        try result.append(entry);
    }

    const payload = std.mem.concat(allocator, u8, result.items) catch {
        return lib.exception.MementoError.GenericError;
    };

    return try createObject(allocator, .tree, payload);
}

pub fn createCommit(tree: [40]u8, parent: ?[40]u8, author: Author, commitMsg: []const u8) lib.exception.MementoError![40]u8 {
    const allocator = std.heap.page_allocator;
    const now = std.time.timestamp();

    const fmt = if (parent == undefined)
        "tree {s}\n{s}author {s} <{s}> {d} 0000\ncommitter {s} <{s}> {d} 0000\n\n{s}\n"
    else
        "tree {s}\nparent {s}\nauthor {s} <{s}> {d} 0000\ncommitter {s} <{s}> {d} 0000\n\n{s}\n";

    const parsedParent = parent orelse "";

    const payload = std.fmt.allocPrint(
        allocator,
        fmt,
        .{ tree, parsedParent, author.name, author.email, now, author.name, author.email, now, commitMsg },
    ) catch {
        return lib.exception.MementoError.GenericError;
    };

    return try createObject(allocator, .commit, payload);
}

fn createObject(allocator: std.mem.Allocator, objType: ObjectType, content: []const u8) lib.exception.MementoError![40]u8 {
    const repo = try lib.repository.openRepository();
    const parsedObjType = toObjectTypeString(objType);
    const payload = std.fmt.allocPrint(
        allocator,
        "{s}\x20{d}\x00{s}",
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
