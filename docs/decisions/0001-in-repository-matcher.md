# 0001 Match with an in-repository engine instead of an external regex engine

## Context

A grok pattern is a template over a regular-expression grammar: `%{WORD:method}`
expands to a word rule whose capture lands in `method`. Two shapes are possible for
the matching layer.

The first shape delegates matching to a general regular-expression engine and
compiles patterns into the dialect of that engine. It is less code, but public
behaviour becomes a function of the dependency: named captures are not guaranteed
across MoonBit regex implementations, so the field map would have to be recovered
from numbered groups by bookkeeping that callers cannot inspect; error positions
would be reported in the terms of the engine rather than in the terms of the
pattern; and every target the project claims (Wasm, JavaScript, native) inherits
the target support of the dependency.

The second shape owns the grammar. Grok patterns need literals, character classes,
quantifiers, non-capturing groups and alternation. That is a small language, and a
backtracking matcher for it fits in a few hundred lines with all behaviour
observable and testable in this repository.

## Decision

The matching layer is implemented here. `syntax` parses pattern text into an AST,
`compile` expands nested patterns and lowers the AST into a matcher program plus a
field table, and `engine` executes that program over one line at a time. No regular
expression package is a dependency of any package in this module.

## Consequences

- Pattern errors are reported against the pattern text with a byte offset and a
  caret line, which an external engine could not produce.
- The supported grammar is fixed here and documented in `docs/limits.md`. A pattern
  that needs a construct outside the grammar is rejected at compile time instead
  of silently mismatching.
- Backtracking has a worst case. The engine bounds search with an explicit step
  budget and reports exhaustion as an error, so a pathological pattern fails
  loudly instead of hanging.
- The matcher is our own code, so the test corpus carries the correctness
  argument. That corpus is also what makes public behaviour defensible in review.