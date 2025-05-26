const std = @import("std");
const lib = @import("lib.zig");

pub const Author = struct {
    name: []const u8,
    email: []const u8,
};

pub const TreeEntry = struct {
    mode: lib.file.FileMode,
    name: []const u8,
    hash: [40]u8,
};

const ObjectHeader = struct {
    objType: ObjectType,
    length: usize,
};

pub const TreeObject = struct {
    header: ObjectHeader,
    entries: []TreeEntry,
};

pub const ObjectType = enum {
    blob,
    tree,
    commit,

    pub fn fromString(objType: []const u8) ObjectType {
        if (std.mem.eql(u8, objType, "tree")) return .tree else if (std.mem.eql(u8, objType, "commit")) return .commit else return .blob;
    }
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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var result = std.ArrayList([]const u8).init(allocator);
    defer result.deinit();

    for (entries) |value| {
        const entry = std.fmt.allocPrint(
            allocator,
            "{s} {s}\x00{s}",
            .{ value.mode.toString(), value.name, value.hash },
        ) catch {
            return lib.exception.MementoError.GenericError;
        };

        result.append(entry) catch {
            return lib.exception.MementoError.GenericError;
        };
    }

    const payload = std.mem.concat(allocator, u8, result.items) catch {
        return lib.exception.MementoError.GenericError;
    };

    defer allocator.free(payload);

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

    defer allocator.free(object_path);

    const object_dir = std.fs.path.dirname(object_path) orelse return lib.exception.MementoError.GenericError;

    _ = repo.makePath(object_dir) catch {
        return lib.exception.MementoError.CouldNotCreateFile;
    };

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

pub fn readObject(allocator: std.mem.Allocator, hash: [40]u8) lib.exception.MementoError![]const u8 {
    const repo = try lib.repository.openRepository();
    const object_path = std.fs.path.join(allocator, &.{ "objects", hash[0..2], hash[2..] }) catch {
        return lib.exception.MementoError.GenericError;
    };

    const file = repo.openFile(object_path, .{}) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer file.close();

    const compressedContent = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer allocator.free(compressedContent);

    return try lib.compress.unzlib(allocator, compressedContent);
}

pub fn parseTreeObject(allocator: std.mem.Allocator, content: []const u8) lib.exception.MementoError!TreeObject {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arenaAllocator = arena.allocator();

    var buffer: []u8 = "";
    var header: ?ObjectHeader = null;

    for (content) |char| {
        if (char == '\x00' and header == null) {
            header = try parseHeader(buffer);

            buffer = "";
            continue;
        }

        buffer = std.mem.concat(arenaAllocator, u8, &[_][]const u8{ buffer, &[_]u8{char} }) catch {
            return lib.exception.MementoError.GenericError;
        };
    }

    const treeEntries = parseTreeEntries(allocator, buffer) catch {
        return lib.exception.MementoError.GenericError;
    };

    const entries = treeEntries.items;

    return TreeObject{
        .header = header.?,
        .entries = entries,
    };
}

pub fn parseTreeEntries(allocator: std.mem.Allocator, data: []const u8) !std.ArrayList(TreeEntry) {
    var entries = std.ArrayList(TreeEntry).init(allocator);
    var i: usize = 0;

    while (i < data.len) {
        const spacePos = std.mem.indexOf(u8, data[i..], " ") orelse break;
        const modeSlice = data[i .. i + spacePos];
        i += spacePos + 1;

        const nullPos = std.mem.indexOf(u8, data[i..], "\x00") orelse return error.InvalidFormat;
        const nameSlice = data[i .. i + nullPos];
        i += nullPos + 1;

        if (i + 40 > data.len) return error.InvalidFormat;
        const hashSlice = data[i .. i + 40];
        i += 40;

        const mode = lib.file.FileMode.fromString(std.mem.trim(u8, modeSlice, " "));
        const name = try allocator.dupe(u8, nameSlice);
        var hashBuf: [40]u8 = undefined;
        std.mem.copyForwards(u8, &hashBuf, hashSlice);

        try entries.append(TreeEntry{
            .mode = mode,
            .name = name,
            .hash = hashBuf,
        });
    }

    return entries;
}

fn parseHeader(content: []u8) lib.exception.MementoError!ObjectHeader {
    var bufferIterator = std.mem.splitScalar(u8, content, ' ');
    const objType = bufferIterator.first();
    const length = bufferIterator.next() orelse return lib.exception.MementoError.GenericError;
    const parsedLength = std.fmt.parseInt(usize, length, 10) catch {
        return lib.exception.MementoError.GenericError;
    };

    return .{ .objType = ObjectType.fromString(objType), .length = parsedLength };
}
