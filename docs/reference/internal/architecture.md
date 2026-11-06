---
title: architecture
type: note
permalink: comptime-casanova/reference/internal/architecture
---

# The Compiler Pipeline

The compiler is a pipeline of stages, each a function from one data shape to the next.
Source text becomes a token stream, then an abstract syntax tree, then a validated tree, then TACKY (a simple intermediate representation), then an assembly tree, then a text file of assembly.
A thin driver at the top shells out to the system C toolchain for preprocessing, assembling, and linking.
This page describes each boundary, so that anything written about one stage can assume the reader knows what "the AST" or "TACKY" refers to.

Each stage is a function that takes data and returns newly built data.
In Zig that means each stage takes an allocator and returns a value it built with that allocator; ownership of the result passes to the caller.
Keeping the stages pure (no hidden global state) is what makes each one independently testable and keeps bugs local.

## The Stages

```
                 preprocessed C text
                        |
   [ lexer ]            v
                   token slice
                        |
   [ parser ]           v
                     AST  (a C program as a tree of tagged unions)
                        |
   [ semantic ]         v
   [ analysis ]      AST  (same shape, now validated and annotated)
                        |
   [ TACKY gen ]        v
                   TACKY IR  (flat list of three-address instructions)
                        |
   [ codegen ]          v
                  assembly AST  (target instructions as data)
                        |
   [ emission ]         v
                  assembly text  (a .s file)
```

Below the `.s` file, the driver calls the assembler and linker to produce an executable.
From Chapter 19 an optimization stage runs between TACKY generation and code generation, taking TACKY to TACKY; it is off unless a driver flag asks for it.

## What Crosses Each Boundary

**Text to tokens (the lexer, `src/lexer.zig`).**
Input is the preprocessed source as one string (a `[]const u8`).
Output is a slice of tokens: keywords, identifiers, integer constants, and punctuation, with whitespace and comments removed.
A token carries its kind (a tagged union) and, where relevant, its text.
The lexer knows nothing about grammar.

**Tokens to AST (the parser, `src/parser.zig` and `src/ast.zig`).**
Input is the token slice.
Output is an abstract syntax tree: a program is a list of functions, a function has a body, a body is a list of statements and declarations, and an expression is a tree of operators over constants and variables.
The AST is a set of tagged unions; recursive nodes hold pointers to child nodes, because a union cannot contain itself by value.
The parser enforces grammar but not meaning.

**AST to AST (semantic analysis, `src/semantic.zig`).**
Input and output are both the AST; the shape does not change, but the tree is checked and lightly annotated.
This catches undeclared and duplicate variables and misplaced `break`, and ties each variable use to its declaration by renaming.
It grows chapter by chapter, and it is not only a check.
It returns the `name_count` that TACKY's counter starts from (from Chapter 5) and a symbol table (from Chapter 9).
From Chapter 11 it also changes the tree: implicit conversions become explicit casts.
Until Chapter 5 it passes the program through unchanged.

**AST to TACKY (TACKY generation, `src/tacky.zig`).**
Input is the validated AST.
Output is TACKY, a three-address IR: a flat list of simple instructions, each operating on named temporaries.
Nested expressions become sequences writing to temporaries; control flow becomes explicit jumps and labels.
This is the key simplification: tree-shaped source becomes list-shaped instructions before anything machine-specific.
The book's Chapter 1 has no IR, but this compiler lowers Chapter 1 through TACKY too, so the driver's stages never change shape.

**TACKY to assembly AST (code generation, `src/codegen.zig`).**
Input is TACKY.
Output is an assembly tree: the target's instructions as data, still using pseudo-locations rather than real registers and stack slots.
A later sub-pass replaces pseudo-locations with stack offsets and fixes up illegal operand combinations.

**Assembly AST to text (code emission, `src/emit.zig`).**
Input is the assembly tree.
Output is the final `.s` text for the platform assembler.
Pure printing.

## Memory Management Is the Zig-Specific Concern

A garbage-collected language would let each stage allocate freely and never free; the book's pseudocode assumes exactly that.
Zig has no garbage collector, so ownership is your job, and the cleanest discipline for a compiler is an **arena allocator**.

An arena hands out memory and frees all of it at once when the arena is deinitialized.
A compiler run is one short-lived batch job that builds a lot of interconnected trees and then exits, which is exactly the case an arena fits.
Allocate every token, AST node, and TACKY instruction from one arena, thread that allocator through every stage, and free the whole arena when compilation finishes.
This removes almost all per-node lifetime reasoning, which is what makes manual memory management painful.
On Zig 0.17 the driver does not build that arena itself; the runtime hands `main` a process arena on `std.process.Init` and reclaims it on exit.

## The Driver

The driver is `main` in `src/main.zig` and the only stage that touches the outside world.
For a source file it:

1. Runs the C preprocessor (`cc -E -P`) to produce the text the lexer reads, then deletes the `.i` file once read.
2. Runs the pipeline above to produce a `.s` file.
3. Runs the assembler and linker (`cc -arch x86_64` on the `.s` file) to produce an executable, then deletes the `.s` file.

The book's test harness invokes the driver with flags that stop the pipeline early (`--lex`, `--parse`, `--validate`, `--tacky`, `--codegen`, `-S`); `-S` keeps the `.s` file, since it is the output.
Support them from the start; they are how you will debug.
In Zig 0.17, shelling out uses `std.process.spawn`, which takes the `Io` handle from `std.process.Init` and returns a `Child` to `wait` on.

## Platform

The book targets x86-64, and so does this compiler, so its instructions match the book's line for line.
On an Apple Silicon Mac the native target is ARM64, with different registers and mnemonics, so the driver builds with `cc -arch x86_64` and Rosetta 2 runs the result.
The emitted assembly differs from the book's Linux output only in macOS spellings: a leading `_` on symbols, macOS section names such as `.literal8` and `.cstring`, no `@PLT`, and no `.note.GNU-stack`.
Keep the target-specific code confined to code generation and emission, exactly as TACKY's position in the pipeline allows.
