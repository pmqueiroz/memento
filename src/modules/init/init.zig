const std = @import("std");
const config = @import("../../config.zig");

fn init(target: std.fs.Dir) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    _ = try target.makeDir(".memento");
    var mementoDir = try target.openDir(".memento", .{ .iterate = true });
    _ = try mementoDir.makeDir("objects");
    _ = try mementoDir.createFile("index", .{});
    const head = try mementoDir.createFile("HEAD", .{});
    defer head.close();
    try head.writeAll("ref: refs/heads/main\n");

    const configFile = try mementoDir.createFile("config", .{});
    defer configFile.close();

    var output = std.ArrayList(u8).init(alloc);
    defer output.deinit();

    try std.zon.stringify.serialize(config.defaultLocalConfig, .{}, output.writer());

    const defaultLocalConfig = try output.toOwnedSlice();

    try configFile.writeAll(defaultLocalConfig);

    std.debug.print("Initialized empty memento repository in {s}\n", .{
        try target.realpathAlloc(alloc, "."),
    });
}

pub fn runInit() !void {
    const cwd = std.fs.cwd();
    try init(cwd);
}

test "it should create .memento correctly" {
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();

    try init(tmp.dir);

    var mementoDir = try tmp.dir.openDir(".memento", .{ .iterate = true });
    _ = try mementoDir.openFile("index", .{});
    var head_file = try mementoDir.openFile("HEAD", .{});
    defer head_file.close();
    var buf: [5]u8 = undefined;
    const n = try head_file.read(buf[0..]);
    try std.testing.expect(n == 5);
    try std.testing.expectEqualStrings("null\n", buf[0..n]);
}
