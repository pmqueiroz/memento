const std = @import("std");
const lib = @import("lib.zig");
const config = @import("../config.zig");

pub const tree = @import("repository/tree.zig");

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

const OpenCommitMsgOptions = union(enum) {
    truncate: bool,
};

pub fn openCommitMsg(options: OpenCommitMsgOptions) lib.exception.MementoError!std.fs.File {
    const repo = try openRepository();
    const commitMsgFile = repo.createFile("COMMIT_EDITMSG", .{ .truncate = options.truncate, .read = true }) catch {
        return lib.exception.MementoError.CouldNotCreateFile;
    };
    return commitMsgFile;
}

pub fn readCommitMsg(allocator: std.mem.Allocator) lib.exception.MementoError![]const u8 {
    const commitMsgFile = try openCommitMsg(.{ .truncate = false });
    defer commitMsgFile.close();

    const buffer = commitMsgFile.readToEndAlloc(allocator, std.math.maxInt(usize)) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer allocator.free(buffer);

    var result = std.ArrayList([]const u8).init(allocator);
    defer result.deinit();

    var bufferIterator = std.mem.splitScalar(u8, buffer, '\n');

    while (bufferIterator.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;

        result.append(line) catch {
            return lib.exception.MementoError.GenericError;
        };
        result.append("\n") catch unreachable;
    }

    if (result.items.len == 0) {
        return lib.exception.MementoError.CommitEmptyMessage;
    }

    const finalResult = std.mem.concat(allocator, u8, result.items) catch {
        return lib.exception.MementoError.GenericError;
    };

    return finalResult;
}

pub fn createCommitMsg(content: []const u8) lib.exception.MementoError!void {
    const commitMsgFile = try openCommitMsg(.{ .truncate = true });
    defer commitMsgFile.close();

    commitMsgFile.writeAll(content) catch {
        return lib.exception.MementoError.UnableToWriteFile;
    };
}

pub fn editCommitMsg() !void {
    var alloc_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc_state.deinit();
    const allocator = alloc_state.allocator();

    const repo = try openRepository();

    const commitMsgPath = try repo.realpathAlloc(allocator, "COMMIT_EDITMSG");

    const commitMsgFile = try openCommitMsg(.{ .truncate = true });
    defer commitMsgFile.close();

    const localConfig = try readConfig(allocator);

    const args: [2][]const u8 = .{ localConfig.core.editor, commitMsgPath };
    var child = std.process.Child.init(&args, allocator);

    std.log.info("Waiting for your editor to close the file...", .{});

    const term = try child.spawnAndWait();

    if (term != .Exited) {
        return lib.exception.MementoError.GenericError;
    }
}

pub fn readConfig(allocator: std.mem.Allocator) lib.exception.MementoError!lib.config.LocalConfig {
    const repo = try openRepository();
    const configFile = repo.openFile("config", .{}) catch {
        return lib.exception.MementoError.NoRepositoryFound;
    };
    defer configFile.close();

    const buffer = configFile.readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0) catch {
        return lib.exception.MementoError.UnableToReadFile;
    };
    defer allocator.free(buffer);

    var status: std.zon.parse.Status = .{};
    const result = std.zon.parse.fromSlice(lib.config.LocalConfig, allocator, buffer[0..], &status, .{}) catch {
        return lib.exception.MementoError.GenericError;
    };

    return result;
}
