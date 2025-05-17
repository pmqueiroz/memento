const std = @import("std");
const cli = @import("zig-cli");
const Init = @import("modules/init/init.zig");
const Index = @import("modules/index/index.zig");

var config = struct {
    files_to_add: []const []const u8 = undefined,
}{};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn parseArgs() cli.AppRunner.Error!cli.ExecFn {
    var r = try cli.AppRunner.init(allocator);
    defer r.deinit();

    const initCmd = cli.Command{
        .name = "init",
        .description = cli.Description{ .one_line = "initialize a new memento repository" },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{ .exec = Init.runInit },
        },
    };

    const indexCmd = cli.Command{
        .name = "index",
        .description = cli.Description{ .one_line = "add files to the index" },
        .target = cli.CommandTarget{
            .action = cli.CommandAction{
                .positional_args = .{ .required = &.{}, .optional = try r.allocPositionalArgs(&.{.{
                    .name = "files",
                    .help = "Files to index",
                    .value_ref = r.mkRef(&config.files_to_add),
                }}) },
                .exec = Index.runIndex,
            },
        },
    };

    const app = cli.App{
        .option_envvar_prefix = "VCS_",
        .command = cli.Command{
            .name = "memento",
            .description = cli.Description{ .one_line = "a simple version control system" },
            .target = cli.CommandTarget{
                .subcommands = try r.allocCommands(&.{ initCmd, indexCmd }),
            },
        },
        // grab version from build.zig.zon as soon as the zon parser support it
        .version = "0.0.0",
        .author = "Peam",
    };

    return r.getAction(&app);
}

pub fn main() anyerror!void {
    const action = try parseArgs();
    const code = action();
    if (gpa.deinit() == .leak) @panic("allocator leaked");
    return code;
}
