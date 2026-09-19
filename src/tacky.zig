const std = @import("std");
const ast = @import("ast.zig");

// TACKY: the three-address IR that sits between the AST and assembly.
// Generation is implemented starting in docs/reference/tacky/ch02-flattening.md.
pub const Program = struct {};

pub fn gen(a: std.mem.Allocator, prog: ast.Program) !Program {
    _ = a;
    _ = prog;
    return error.NotImplemented;
}
