const std = @import("std");

pub const Token = union(enum) {
    kw_int: void,
    kw_void: void,
    kw_return: void,
    identifier: []const u8,
    constant: i64,
    l_paren: void,
    r_paren: void,
    l_brace: void,
    r_brace: void,
    semicolon: void,
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

// an identifier byte after the first: a leading char or a digit
fn isIdentContinue(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}

// first index at or after i whose byte fails pred
fn scanWhile(src: []const u8, i: usize, pred: *const fn (u8) bool) usize {
    var j = i;
    while (j < src.len and pred(src[j])) : (j += 1) {}
    return j;
}

fn keywordOf(text: []const u8) ?Token {
    if (std.mem.eql(u8, text, "int")) return .kw_int;
    if (std.mem.eql(u8, text, "void")) return .kw_void;
    if (std.mem.eql(u8, text, "return")) return .kw_return;
    return null;
}

pub fn tokenize(a: std.mem.Allocator, src: []const u8) ![]Token {
    var out: std.ArrayList(Token) = .empty;
    var i: usize = 0;

    while (i < src.len) {
        const c = src[i];
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            i += 1;
        } else if (isDigit(c)) {
            const j = scanWhile(src, i, isDigit);
            // a constant may not run straight into an identifier char: 123abc
            if (j < src.len and isAlpha(src[j])) return error.BadNumber;
            const n = try std.fmt.parseInt(i64, src[i..j], 10);
            try out.append(a, .{ .constant = n });
            i = j;
        } else if (isAlpha(c)) {
            const j = scanWhile(src, i, isIdentContinue);
            const text = src[i..j];
            try out.append(a, keywordOf(text) orelse Token{ .identifier = text });
            i = j;
        } else {
            const tok: Token = switch (c) {
                '(' => .l_paren,
                ')' => .r_paren,
                '{' => .l_brace,
                '}' => .r_brace,
                ';' => .semicolon,
                else => return error.UnexpectedChar,
            };
            try out.append(a, tok);
            i += 1;
        }
    }
    return out.items;
}
