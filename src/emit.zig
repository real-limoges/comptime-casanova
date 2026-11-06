const std = @import("std");
const codegen = @import("codegen.zig");

const Reg = codegen.Reg;
const Operand = codegen.Operand;
const Instruction = codegen.Instruction;
const Program = codegen.Program;

// Code emission: prints the assembly tree as AT&T syntax for macOS x86-64,
// so symbols carry a leading underscore and there is no GNU-stack note. The
// driver assembles the result with `cc -arch x86_64` and Rosetta 2 runs it.

fn regName(r: Reg) []const u8 {
    return switch (r) {
        .ax => "%eax",
    };
}

fn emitOperand(w: anytype, op: Operand) !void {
    switch (op) {
        .imm => |n| try w.print("${d}", .{n}),
        .reg => |r| try w.writeAll(regName(r)),
    }
}

fn emitInstruction(w: anytype, ins: Instruction) !void {
    switch (ins) {
        .mov => |m| {
            try w.writeAll("\tmovl ");
            try emitOperand(w, m.src);
            try w.writeAll(", ");
            try emitOperand(w, m.dst);
            try w.writeByte('\n');
        },
        .ret => try w.writeAll("\tmovq %rbp, %rsp\n\tpopq %rbp\n\tret\n"),
    }
}

pub fn emitProgram(w: anytype, prog: Program) !void {
    const f = prog.function;
    try w.print("\t.globl _{s}\n_{s}:\n", .{ f.name, f.name });
    try w.writeAll("\tpushq %rbp\n\tmovq %rsp, %rbp\n");
    for (f.instructions) |ins| try emitInstruction(w, ins);
}

pub fn toFile(a: std.mem.Allocator, prog: Program, path: []const u8) !void {
    var aw: std.Io.Writer.Allocating = .init(a);
    try emitProgram(&aw.writer, prog);
    const io = std.Io.Threaded.global_single_threaded.io();
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = aw.writer.buffered() });
}
