const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

// Recursive-descent + precedence-climbing parser.
// Implemented starting in docs/reference/parser/ch01-minimal.md.
pub fn parse(a: std.mem.Allocator, tokens: []const lexer.Token) !ast.Program {
    _ = a;
    _ = tokens;
    return error.NotImplemented;
}
