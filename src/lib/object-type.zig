pub const ObjectType = enum {
    blob,
    commit,
    branch,
};

pub fn toObjectTypeString(objType: ObjectType) []const u8 {
    const result = switch (objType) {
        .blob => "blob",
        .commit => "commit",
        .branch => "branch",
    };
    return result;
}

test "it should return the correct string for each object type" {
    const std = @import("std");
    const blobStr = toObjectTypeString(ObjectType.blob);
    const commitStr = toObjectTypeString(ObjectType.commit);
    const branchStr = toObjectTypeString(ObjectType.branch);

    try std.testing.expectEqualStrings(blobStr, "blob");
    try std.testing.expectEqualStrings(commitStr, "commit");
    try std.testing.expectEqualStrings(branchStr, "branch");
}
