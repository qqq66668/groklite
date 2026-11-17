# Limits

This file states what the library does not do. Read it before the README example:
a wrong expectation costs more than a missing feature.

## Grammar

Supported: literals, the shorthand classes for digits, word characters and
whitespace, explicit character sets including negation, the quantifiers star, plus,
question mark and bounded repetition, non-capturing groups, alternation over those
elements, and start and end anchors.

Not supported, and rejected at compile time where the construct is recognised:

- lookahead and lookbehind;
- backreferences;
- lazy quantifiers;
- named capture groups inside a pattern body;
- inline flags such as case-insensitive mode. Use an explicit character set.

## Input

- Matching is line oriented. A caller that needs multi-line matching splits input
  and merges results.
- Offsets reported in errors are character offsets into the pattern text, counted
  in code units rather than bytes.
- No normalisation happens. A full-width digit does not match a digit class.

## Output

- Field values are strings. Coercion to integers, timestamps or booleans stays
  outside the library.
- Field order follows pattern order. A consumer with another ordering requirement
  re-keys the result.
- A line that fails to match returns an error, never a partial map. There is no
  best-effort mode.

## Performance

- A single pass is bounded by a step budget, not by wall-clock time. Exhaustion is
  an error, not a hang and not a partial result.
- A repetition whose body consumes no characters is not repeated, so a starred empty
  group cannot loop forever.
- Matching is whole-line. A pattern that matches only a prefix reports no match; a
  caller that wants a prefix match anchors the pattern itself.
- No throughput figure is published. A number would describe one machine and one
  backend, while this repository tests several targets rather than one measurement
  host, so a figure in this file could not be reproduced from the repository.
  What is published instead is the shape of the cost: matching backtracks over the
  compiled program, the search is bounded by the step budget, and that budget is a
  parameter a caller can lower.

## Scope

- No file input, no network input, no log shipping. The library takes a string and
  returns a value.
- No pattern discovery from a directory at runtime. Patterns are compiled from text
  the caller already holds.
## Post-match stages

- Record assembly is line oriented: a record is a run of physical lines, and the
  only continuation signals are indentation and literal prefixes. Detecting that a
  line is a stack frame by parsing the language it came from is out of scope.
- Static analysis reports bounds, not performance. A step bound is the number of
  instructions the search may visit, not a wall-clock estimate.
- Field contracts validate the text a pattern produced. They do not coerce types:
  an integer check reports whether the text parses, it does not rewrite the map.
- A cross-field comparison runs only when both sides parse as integers; a
  non-integer side is reported, not skipped silently.
## Numbers and streams

- A field is read as a signed 32-bit integer. A magnitude that does not fit is
  reported, never wrapped; wrapping would let an out-of-range value satisfy a
  range check.
- `structure_steps` counts instruction visits in the compiled tree. A backtracking
  search can visit more instructions than the tree contains, so the number compares
  patterns and is not a budget for the engine.
- Stream assembly holds one record in memory at a time. A record that never ends
  (no blank line, no new header) grows without bound; that is the caller's input,
  not a library limit.
## Failure reports

- A failed match reports the furthest position the search reached and the
  instruction it was trying there. That is a diagnostic, not a proof: with
  alternation, the deepest point may belong to a branch that could never have
  completed.
- The summary line of a failure is stable; the detail line is meant for a person
  writing a pattern.
