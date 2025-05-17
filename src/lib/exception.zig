pub const MementoError = error{
    NoFilesToIndex,
};

pub fn isMementoError(err: anyerror) bool {
    return err == MementoError.NoFilesToIndex;
}

pub fn translateError(err: anyerror) ![]const u8 {
    const translate = try switch (err) {
        MementoError.NoFilesToIndex => "No files to index",
        else => err,
    };

    return translate;
}

test "[isMementoError] it should return if error is MementoError" {
    const std = @import("std");
    const result = isMementoError(MementoError.NoFilesToIndex);
    try std.testing.expectEqual(result, true);
}

test "[translateError] it should return the correct string for MementoError" {
    const std = @import("std");
    const result = translateError(MementoError.NoFilesToIndex);
    try std.testing.expectEqualStrings(result, "No files to index");
}
