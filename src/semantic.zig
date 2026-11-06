const std = @import("std");
const ast = @import("ast.zig");

// Semantic analysis (the --validate stage): name resolution and, in Part II,
// type checking. Returns the validated tree. A pass-through until Chapter 5
// adds variable resolution; each pass joins `check` when its chapter arrives.
pub fn check(a: std.mem.Allocator, prog: ast.Program) !ast.Program {
    _ = a;
    return prog;
}
