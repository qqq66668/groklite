# Design

## Layers

Four packages with one direction of dependency:

- `syntax` turns pattern text into an AST and reports offsets. It knows nothing
  about matching.
- `registry` maps a pattern name to a pattern body. It knows nothing about parsing
  or matching.
- `compile` walks the AST, expands registry references recursively, detects cycles
  and lowers the result into a program with numbered slots plus a field table.
- `engine` executes a program over one line and returns a field map or an error. It
  knows nothing about pattern syntax.

`src/lib.mbt` is the only package with public exports. The four packages above are
internal and reach callers only through it.

## Why compilation is separate from matching

Compilation is where every static error can be caught: unknown pattern name,
unbalanced delimiter, duplicate field, expansion cycle, unsupported construct.
Doing that work once means the hot path carries no checks that can surprise a
caller, and every error is reported with a position in the pattern text instead of
a position in the input line.

## Invariants

1. No package performs input or output: no file system, no network, no clock.
2. `engine` never parses pattern text and never consults the registry.
3. Every failure is one error type carrying an offset, and the rendered form points
   at the offending position.
4. Compilation is deterministic: the same pattern and registry produce the same
   slot numbering on every run and every target.
5. Expansion depth and step count are both bounded; exceeding either is an error.

## Field numbering

Each capture slot is numbered in pattern order at compile time. The field table
maps slot number to field name, so a caller-facing map is built without relying on
engine support for named groups. This is the reason the project needs no
regular-expression package.

## Testing shape

- Unit tests sit next to the package they test.
- `test/` is a black-box package driven by corpus files: one input line per case
  plus the expected field map, so a behaviour change appears as a data diff.
- The example under `examples/` is compiled and run in continuous integration,
  which keeps the README honest.