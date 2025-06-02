pub const MementoError = error{
    NoFilesToIndex,
    FileNotFound,
    GenericError,
    NoRepositoryFound,
    UnableToReadFile,
    UnableToWriteFile,
    CouldNotCreateFile,
    RawIsNotAnValidRecordEntry,
    CommitEmptyMessage,
    NoBranchFound,
};

pub fn isMementoError(err: anyerror) bool {
    return err == MementoError.NoFilesToIndex or
        err == MementoError.FileNotFound or
        err == MementoError.GenericError or
        err == MementoError.NoRepositoryFound or
        err == MementoError.UnableToReadFile or
        err == MementoError.UnableToWriteFile or
        err == MementoError.CouldNotCreateFile or
        err == MementoError.RawIsNotAnValidRecordEntry or
        err == MementoError.CommitEmptyMessage or
        err == MementoError.NoBranchFound;
}

pub fn translateError(err: anyerror) []const u8 {
    const translate = switch (err) {
        MementoError.NoFilesToIndex => "No files to index",
        MementoError.FileNotFound => "File not found",
        MementoError.GenericError => "Generic error",
        MementoError.NoRepositoryFound => "No repository found",
        MementoError.UnableToReadFile => "Unable to read file",
        MementoError.CouldNotCreateFile => "Unable to create file",
        MementoError.RawIsNotAnValidRecordEntry => "Raw is not a valid record entry",
        MementoError.UnableToWriteFile => "Unable to write file",
        MementoError.CommitEmptyMessage => "Commit message is empty",
        MementoError.NoBranchFound => "No branch found",
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
