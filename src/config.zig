pub var files_to_add: []const []const u8 = undefined;
pub var commit_message: []const u8 = undefined;

pub const LocalConfig = struct {
    core: struct {
        editor: []const u8,
    },
};

pub const defaultLocalConfig = .{ .core = .{
    .editor = "vim",
} };
