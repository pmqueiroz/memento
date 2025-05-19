const std = @import("std");
const lib = @import("../../lib/lib.zig");
const config = @import("../../config.zig");

fn commit() !void {
    const allocator = std.heap.page_allocator;

    const commitMsg = try lib.repository.readCommitMsg(allocator);
    defer allocator.free(commitMsg);

    std.debug.print("Committing changes...{s}\n", .{commitMsg});
}

pub fn runCommit() !void {
    if (config.commit_message.len > 0) {
        try lib.repository.createCommitMsg(config.commit_message);
    } else {
        try lib.repository.editCommitMsg();
    }

    try commit();
}
