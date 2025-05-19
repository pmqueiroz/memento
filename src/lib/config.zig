pub const LocalConfig = struct {
    core: struct {
        editor: []const u8,
    },
};

pub const defaultLocalConfig = .{ .core = .{
    .editor = "vim",
} };
