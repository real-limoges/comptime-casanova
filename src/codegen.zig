const std = @import("std");
const tacky = @import("tacky.zig");

// Assembly generation: lowers TACKY to the assembly AST in three sub-passes
// (translate, assign stack slots, fix up illegal instructions).

pub const Reg = enum { ax };

pub const Operand = union(enum) {
    imm: i64,
    reg: Reg,
};

pub const Instruction = union(enum) {
    mov: struct { src: Operand, dst: Operand },
    ret: void,
};

pub const FunctionDef = struct { name: []const u8, instructions: []Instruction };

pub const Program = struct { function: FunctionDef };

pub fn gen(a: std.mem.Allocator, ir: tacky.Program) !Program {
    return .{ .function = try genFunction(a, ir.function) };
}

fn genFunction(a: std.mem.Allocator, fun: tacky.FunctionDef) !FunctionDef {
    const selected = try selectInstructions(a, fun); // pass 1
    const slotted = replacePseudos(selected); // pass 2
    const fixed = fixUp(slotted); // pass 3
    return .{ .name = fun.name, .instructions = fixed };
}

fn operandOf(v: tacky.Value) Operand {
    return switch (v) {
        .constant => |n| .{ .imm = n },
    };
}

// Pass 1: each TACKY instruction becomes one or a few assembly instructions.
fn selectInstructions(a: std.mem.Allocator, fun: tacky.FunctionDef) ![]Instruction {
    var out: std.ArrayList(Instruction) = .empty;
    for (fun.body) |instr| switch (instr) {
        .ret => |v| {
            try out.append(a, .{ .mov = .{ .src = operandOf(v), .dst = .{ .reg = .ax } } });
            try out.append(a, .ret);
        },
    };
    return out.toOwnedSlice(a);
}

// Pass 2: Chapter 1 has no pseudo-locations, so there is nothing to slot.
fn replacePseudos(instrs: []Instruction) []Instruction {
    return instrs;
}

// Pass 3: Chapter 1 has no illegal operand combinations to fix.
fn fixUp(instrs: []Instruction) []Instruction {
    return instrs;
}
