const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

const Token = lexer.Token;
const Exp = ast.Exp;
const Statement = ast.Statement;
const FunctionDef = ast.FunctionDef;

const Parser = struct {
    tokens: []const Token,
    pos: usize = 0,
    a: std.mem.Allocator,

    fn peek(p: *Parser) ?Token {
        return if (p.pos < p.tokens.len) p.tokens[p.pos] else null;
    }
    fn advance(p: *Parser) Token {
        const t = p.tokens[p.pos];
        p.pos += 1;
        return t;
    }
    fn expect(p: *Parser, tag: std.meta.Tag(Token)) !Token {
        const t = p.peek() orelse return error.UnexpectedEof;
        if (std.meta.activeTag(t) != tag) return error.UnexpectedToken;
        return p.advance();
    }
    fn makeExp(p: *Parser, value: Exp) !*Exp {
        const node = try p.a.create(Exp);
        node.* = value;
        return node;
    }
    fn parseExp(p: *Parser) !*Exp {
        const t = try p.expect(.constant);
        return p.makeExp(.{ .constant = t.constant });
    }
    fn parseStatement(p: *Parser) !Statement {
        _ = try p.expect(.kw_return);
        const e = try p.parseExp();
        _ = try p.expect(.semicolon);
        return .{ .ret = e };
    }
    fn parseFunction(p: *Parser) !FunctionDef {
        _ = try p.expect(.kw_int);
        const name = (try p.expect(.identifier)).identifier;
        _ = try p.expect(.l_paren);
        _ = try p.expect(.kw_void);
        _ = try p.expect(.r_paren);
        _ = try p.expect(.l_brace);
        const body = try p.parseStatement();
        _ = try p.expect(.r_brace);
        return .{ .name = name, .body = body };
    }
};

// Recursive-descent + precedence-climbing parser.
pub fn parse(a: std.mem.Allocator, tokens: []const Token) !ast.Program {
    var p = Parser{ .tokens = tokens, .a = a };
    const fn_def = try p.parseFunction();
    if (p.peek() != null) return error.TrailingTokens;
    return .{ .function = fn_def };
}

// lex then parse, for the tests below
fn parseSource(a: std.mem.Allocator, src: []const u8) !ast.Program {
    return parse(a, try lexer.tokenize(a, src));
}

test "parses the minimal program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const prog = try parseSource(arena.allocator(), "int main(void){return 2;}");
    try std.testing.expectEqualStrings("main", prog.function.name);
    try std.testing.expectEqual(@as(i64, 2), prog.function.body.ret.constant);
}

test "rejects a missing semicolon" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(error.UnexpectedToken, parseSource(arena.allocator(), "int main(void){return 2}"));
}

test "rejects a keyword where an expression belongs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(error.UnexpectedToken, parseSource(arena.allocator(), "int main(void){return int;}"));
}

test "rejects a missing closing brace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(error.UnexpectedEof, parseSource(arena.allocator(), "int main(void){return 2;"));
}

test "rejects tokens after the function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectError(error.TrailingTokens, parseSource(arena.allocator(), "int main(void){return 2;} foo"));
}
