const std = @import("std");

fn vcsInit() !void {
    const cwd = std.fs.cwd();
    _ = try cwd.makeDir(".vcs");
    var vcsDir = try cwd.openDir(".vcs", .{ .iterate = true });
    _ = try vcsDir.makeDir("objects");
    _ = try vcsDir.createFile("index", .{});
    var head = try vcsDir.createFile("HEAD", .{});
    _ = try head.writeAll("null\n");
    head.close();
    std.debug.print("Initialized empty VCS repository in .vcs\n", .{});
}

pub fn runInit() !void {
    try vcsInit();
}
