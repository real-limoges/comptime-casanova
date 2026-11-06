// The parser's output: the abstract syntax tree.
//
// Chapter 1's tree: one function whose body is a `return` of a constant.
// Each later chapter adds the cases its language feature needs.

pub const Exp = union(enum) {
    constant: i64,
};

pub const Statement = union(enum) {
    ret: *Exp,
};

pub const FunctionDef = struct {
    name: []const u8,
    body: Statement,
};

pub const Program = struct { function: FunctionDef };
