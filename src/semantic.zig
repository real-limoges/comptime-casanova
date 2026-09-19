const std = @import("std");
const ast = @import("ast.zig");

// Semantic analysis (the --validate stage): name resolution and, in Part II,
// type checking. Returns the validated tree. A no-op placeholder until the
// chapters that introduce it.
pub fn check(a: std.mem.Allocator, prog: ast.Program) !ast.Program {
    _ = a;
    _ = prog;
    return error.NotImplemented;
}
