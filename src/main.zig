const std = @import("std");
const Io = std.Io;

const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const semantic = @import("semantic.zig");
const tacky = @import("tacky.zig");
const codegen = @import("codegen.zig");
const emit = @import("emit.zig");

// How far to run the pipeline. The book's test harness passes the flags that
// stop it early; `.link` (no flag) runs all the way to an executable.
const Stage = enum { lex, parse, validate, tacky, codegen, assembly, link };

const Options = struct {
    stage: Stage,
    input: []const u8, // the .c file named on the command line
    i_path: []const u8, // preprocessed source (cc -E) that we actually lex
    asm_path: []const u8, // the .s file emission writes
    exe_path: []const u8, // the linked executable
};

// Run a subprocess to completion, inheriting our stdio; any nonzero exit is an
// error. Zig 0.16 routes process control through the `Io` interface.
fn run(io: Io, argv: []const []const u8) !void {
    var child = try std.process.spawn(io, .{ .argv = argv });
    const term = try child.wait(io);
    if (term != .exited or term.exited != 0) return error.SubprocessFailed;
}

fn preprocess(io: Io, input: []const u8, i_path: []const u8) !void {
    try run(io, &.{ "cc", "-E", "-P", input, "-o", i_path });
}

fn assembleLink(io: Io, asm_path: []const u8, exe_path: []const u8) !void {
    try run(io, &.{ "cc", asm_path, "-o", exe_path });
}

fn readFile(io: Io, a: std.mem.Allocator, path: []const u8) ![]u8 {
    return Io.Dir.cwd().readFileAlloc(io, path, a, .unlimited);
}

fn parseArgs(a: std.mem.Allocator, argv: []const [:0]const u8) !Options {
    var stage: Stage = .link;
    var input: ?[]const u8 = null;
    for (argv[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--lex")) {
            stage = .lex;
        } else if (std.mem.eql(u8, arg, "--parse")) {
            stage = .parse;
        } else if (std.mem.eql(u8, arg, "--validate")) {
            stage = .validate;
        } else if (std.mem.eql(u8, arg, "--tacky")) {
            stage = .tacky;
        } else if (std.mem.eql(u8, arg, "--codegen")) {
            stage = .codegen;
        } else if (std.mem.eql(u8, arg, "-S")) {
            stage = .assembly;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("unknown flag: {s}\n", .{arg});
            return error.UnknownFlag;
        } else {
            input = arg;
        }
    }

    const in = input orelse {
        std.debug.print(
            "usage: ccc [--lex|--parse|--validate|--tacky|--codegen|-S] <input.c>\n",
            .{},
        );
        return error.NoInput;
    };

    // Derive the sibling paths from the input by dropping a trailing ".c".
    const base = if (std.mem.endsWith(u8, in, ".c")) in[0 .. in.len - 2] else in;
    return .{
        .stage = stage,
        .input = in,
        .i_path = try std.fmt.allocPrint(a, "{s}.i", .{base}),
        .asm_path = try std.fmt.allocPrint(a, "{s}.s", .{base}),
        .exe_path = try a.dupe(u8, base),
    };
}

pub fn main(init: std.process.Init) !void {
    // The runtime hands us a process-lifetime arena; every stage allocates
    // into it and never frees. `io` is how we touch files and subprocesses.
    const a = init.arena.allocator();
    const io = init.io;

    const opts = try parseArgs(a, try init.minimal.args.toSlice(a));
    try preprocess(io, opts.input, opts.i_path);
    const text = try readFile(io, a, opts.i_path);

    const tokens = try lexer.tokenize(a, text);
    if (opts.stage == .lex) return;
    const ast_prog = try parser.parse(a, tokens);
    if (opts.stage == .parse) return;
    const checked = try semantic.check(a, ast_prog);
    if (opts.stage == .validate) return;
    const ir = try tacky.gen(a, checked);
    if (opts.stage == .tacky) return;
    const asm_prog = try codegen.gen(a, ir);
    if (opts.stage == .codegen) return;
    try emit.toFile(a, asm_prog, opts.asm_path);
    if (opts.stage == .assembly) return;
    try assembleLink(io, opts.asm_path, opts.exe_path);
}
