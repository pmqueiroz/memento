const std = @import("std");
const lib = @import("../../lib/lib.zig");

fn status(repo: std.fs.Dir) !void {
    const allocator = std.heap.page_allocator;
    const branch = try lib.repository.tree.getWorkingTree(allocator, repo);
    std.debug.print("Current working tree: {s}\n", .{branch.name});
}

pub fn runStatus() !void {
    var repo = try lib.repository.openRepository();
    defer repo.close();

    try status(repo);
}
