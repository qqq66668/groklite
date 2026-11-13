# Changelog

Unreleased work sits under `Unreleased` and moves under a version heading when a
version is cut.

## Unreleased

- Repository baseline: licence, line-ending policy, editor policy, decision log and
  the hygiene gate.
- Pattern syntax layer: parse pattern text into literal and reference segments.
- Pattern registry: curated built-in subset with recursive expansion, cycle, depth
  and nested-field errors.
- Rule grammar: bracket classes, shorthand escapes, groups, alternation, anchors and
  bounded repetition lowered into a node tree with positioned errors.
- Compilation: pattern segments lowered into a capture-numbered program plus a
  field table, with duplicate-field, unknown-rule and empty-pattern errors.
- Matching: one line executed against a compiled program into a field table, with a
  whole-line rule, a bounded step budget and named field lookups.
- Corpus: a black-box test package driving the facade from a table of input lines and
  expected field maps, plus one runnable example that continuous integration executes.
- Registry: the syslog family (month, month day, time, timestamp, program and a
  composite base rule) joins the curated subset, with corpus rows for the RFC 3164 prefix.
- Matching: `match_first` tries compiled programs in order and reports the first whole
  line match, with a per-program step budget and one failure for the whole list.
- Example: `examples/syslog_to_json` parses a syslog line with the first matching
  pattern, and continuous integration runs both examples.