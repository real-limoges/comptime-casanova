const std = @import("std");
const tacky = @import("tacky.zig");

// Assembly generation: lowers TACKY to the assembly AST in three sub-passes
// (translate, assign stack slots, fix up illegal instructions). See
// docs/reference/codegen/stage-4-codegen.md.
pub const Program = struct {};

pub fn gen(a: std.mem.Allocator, ir: tacky.Program) !Program {
    _ = a;
    _ = ir;
    return error.NotImplemented;
}
