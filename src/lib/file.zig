const std = @import("std");

const REGULAR: []const u8 = "100644";
const EXECUTABLE: []const u8 = "100755";
const SYMLINK: []const u8 = "120000";

pub const FileMode = enum {
    regular,
    executable,
    symlink,

    pub fn toString(self: FileMode) []const u8 {
        return switch (self) {
            .regular => REGULAR,
            .executable => EXECUTABLE,
            .symlink => SYMLINK,
        };
    }

    pub fn fromString(mode: []const u8) FileMode {
        if (std.mem.eql(u8, mode, EXECUTABLE)) return .executable else if (std.mem.eql(u8, mode, SYMLINK)) return .symlink else return .regular;
    }
};

pub fn fileModeFromStat(stat: std.fs.File.Stat) FileMode {
    const is_exec = stat.mode & 0o111 != 0;

    return if ((stat.mode & 0o170000) == 0o120000)
        FileMode.symlink
    else if (is_exec)
        FileMode.executable
    else
        FileMode.regular;
}
