const std = @import("std");
const ast = @import("ast.zig");

// TACKY: the three-address IR that sits between the AST and assembly.
// Chapter 1's slice is a single `ret` of a constant; flattening nested
// expressions into temporaries arrives with Chapter 2's unary operators.

pub const Value = union(enum) {
    constant: i64,
};

pub const Instruction = union(enum) {
    ret: Value,
};

pub const FunctionDef = struct { name: []const u8, body: []Instruction };

pub const Program = struct { function: FunctionDef };

fn valueOf(e: *const ast.Exp) Value {
    return switch (e.*) {
        .constant => |n| .{ .constant = n },
    };
}

pub fn gen(a: std.mem.Allocator, prog: ast.Program) !Program {
    var instrs: std.ArrayList(Instruction) = .empty;
    switch (prog.function.body) {
        .ret => |e| try instrs.append(a, .{ .ret = valueOf(e) }),
    }
    // the implicit `return 0` at the end of main
    try instrs.append(a, .{ .ret = .{ .constant = 0 } });
    return .{ .function = .{
        .name = prog.function.name,
        .body = try instrs.toOwnedSlice(a),
    } };
}
