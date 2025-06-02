const std = @import("std");
const lib = @import("../../lib/lib.zig");

pub const Head = struct {
    raw: []const u8,
    detached: bool,
};

pub const WorkingTree = struct {
    path: []const u8,
    name: []const u8,
};

fn parseHEAD(allocator: std.mem.Allocator, repo: std.fs.Dir) lib.exception.MementoError!Head {
    var result = std.ArrayList(u8).init(allocator);

    const headFile = repo.openFile("HEAD", .{}) catch {
        return lib.exception.MementoError.NoRepositoryFound;
    };
    defer headFile.close();

    const buffer = headFile.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer allocator.free(buffer);

    if (buffer.len == 0) {
        return lib.exception.MementoError.NoBranchFound;
    }

    if (buffer[3] == ':') {
        result.appendSlice(buffer[5 .. buffer.len - 1]) catch {
            return lib.exception.MementoError.GenericError;
        };
        return Head{
            .detached = false,
            .raw = result.toOwnedSlice() catch {
                return lib.exception.MementoError.GenericError;
            },
        };
    }

    if (buffer.len == 41) {
        result.appendSlice(buffer[0..40]) catch {
            return lib.exception.MementoError.GenericError;
        };

        return Head{
            .detached = true,
            .raw = result.toOwnedSlice() catch {
                return lib.exception.MementoError.GenericError;
            },
        };
    }

    return lib.exception.MementoError.NoBranchFound;
}

pub fn getWorkingTree(allocator: std.mem.Allocator, repo: std.fs.Dir) lib.exception.MementoError!WorkingTree {
    const head = try parseHEAD(allocator, repo);
    if (head.detached) {
        return WorkingTree{
            .name = head.raw,
            .path = std.fmt.allocPrint(allocator, "objects/{s}/{s}", .{
                head.raw[0..2],
                head.raw[2..],
            }) catch {
                return lib.exception.MementoError.GenericError;
            },
        };
    }
    return WorkingTree{ .name = head.raw[11..], .path = head.raw };
}
