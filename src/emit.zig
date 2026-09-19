const std = @import("std");
const codegen = @import("codegen.zig");

// Emission: prints the assembly AST to a .s file at asm_path. See
// docs/reference/emission/stage-5-emission.md.
pub fn toFile(a: std.mem.Allocator, asm_prog: codegen.Program, asm_path: []const u8) !void {
    _ = a;
    _ = asm_prog;
    _ = asm_path;
    return error.NotImplemented;
}
