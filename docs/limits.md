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
- No throughput claim is made here. A number appears only after a benchmark target
  exists and runs in continuous integration.

## Scope

- No file input, no network input, no log shipping. The library takes a string and
  returns a value.
- No pattern discovery from a directory at runtime. Patterns are compiled from text
  the caller already holds.