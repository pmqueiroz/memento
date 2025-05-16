const std = @import("std");

fn vcsInit(target: std.fs.Dir) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    _ = try target.makeDir(".vcs");
    var vcsDir = try target.openDir(".vcs", .{ .iterate = true });
    _ = try vcsDir.makeDir("objects");
    _ = try vcsDir.createFile("index", .{});
    var head = try vcsDir.createFile("HEAD", .{});
    _ = try head.writeAll("null\n");
    head.close();

    std.debug.print("Initialized empty VCS repository in {s}\n", .{
        try target.realpathAlloc(alloc, "."),
    });
}

pub fn runInit() !void {
    const cwd = try std.fs.cwd();
    try vcsInit(cwd);
}

test "it should create .vcs correctly" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    try vcsInit(tmp.dir);

    var vcsDir = try tmp.dir.openDir(".vcs", .{ .iterate = true });
    _ = try vcsDir.openFile("index", .{});
    var head_file = try vcsDir.openFile("HEAD", .{});
    defer head_file.close();
    var buf: [5]u8 = undefined;
    const n = try head_file.read(buf[0..]);
    try std.testing.expect(n == 5);
    try std.testing.expectEqualStrings("null\n", buf[0..n]);
}
