const std = @import("std");
const cli = @import("zig-cli");
const config = @import("config.zig");
const lib = @import("lib/lib.zig");
const Init = @import("modules/init/init.zig");
const Add = @import("modules/add/add.zig");
const Status = @import("modules/status/status.zig");
const Commit = @import("modules/commit/commit.zig");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var r = try cli.AppRunner.init(allocator);
    defer r.deinit();

    const initCmd = cli.Command{
        .name = "init",
        .description = cli.Description{ .one_line = "initialize a new memento repository" },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{ .exec = Init.runInit },
        },
    };

    const addCmd = cli.Command{
        .name = "add",
        .description = cli.Description{ .one_line = "add files to the index" },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .positional_args = .{ .required = &.{}, .optional = try r.allocPositionalArgs(&.{.{
                    .name = "files",
                    .help = "Files to index",
                    .value_ref = r.mkRef(&config.files_to_add),
                }}) },
                .exec = Add.runAdd,
            },
        },
    };

    const statusCmd = cli.Command{
        .name = "status",
        .description = cli.Description{ .one_line = "show the working tree status" },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .exec = Status.runStatus,
            },
        },
    };

    const commitCmd = cli.Command{
        .name = "commit",
        .description = cli.Description{ .one_line = "Record changes to the repository" },
        .options = try r.allocOptions(&.{.{
            .long_name = "message",
            .short_alias = 'm',
            .help = "Commit message",
            .required = false,
            .value_ref = r.mkRef(&config.commit_message),
        }}),
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .exec = Commit.runCommit,
            },
        },
    };

    const app = cli.App{
        .option_envvar_prefix = "MEMENTO_",
        .command = cli.Command{
            .name = "memento",
            .description = cli.Description{ .one_line = "a simple version control system" },
            .target = cli.CommandTarget{
                .subcommands = try r.allocCommands(&.{ initCmd, addCmd, commitCmd, statusCmd }),
            },
        },
        .version = "0.0.0",
        .author = "Peam",
    };

    const action = try r.getAction(&app);
    _ = action() catch |err| {
        if (lib.exception.isMementoError(err)) {
            const translated = lib.exception.translateError(err);
            std.log.err("{s}\n", .{translated});
            std.process.exit(1);
        }
    };
}
