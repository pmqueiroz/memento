pub const MementoError = error{
    NoFilesToIndex,
    FileNotFound,
    GenericError,
    NoRepositoryFound,
    UnableToReadFile,
    CouldNotCreateFile,
};

pub fn isMementoError(err: anyerror) bool {
    return err == MementoError.NoFilesToIndex or
        err == MementoError.FileNotFound or
        err == MementoError.GenericError or
        err == MementoError.NoRepositoryFound or
        err == MementoError.UnableToReadFile or
        err == MementoError.CouldNotCreateFile;
}

pub fn translateError(err: anyerror) []const u8 {
    const translate = switch (err) {
        MementoError.NoFilesToIndex => "No files to index",
        MementoError.FileNotFound => "File not found",
        MementoError.GenericError => "Generic error",
        MementoError.NoRepositoryFound => "No repository found",
        MementoError.UnableToReadFile => "Unable to read file",
        MementoError.CouldNotCreateFile => "Unable to create file",
        else => "Unknown error",
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
