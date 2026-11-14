# Changelog

Unreleased work sits under `Unreleased` and moves under a version heading when a
version is cut.

## Unreleased

Nothing yet.

## 0.1.2 - 2026-11-14

- Build: `moon fmt` is applied across the module and a formatting gate in CI and in
- Continuous integration: a target matrix runs the suite again on wasm-gc and js, so
- Documentation: `docs/limits.md` no longer promises a future throughput number and
- Documentation: `README.md` gained an install and usage section for
- Release: the published package carries the install section, the target matrix and
  the edited limits file, so the package and the repository no longer disagree.
## 0.1.1 - 2026-11-14

- Documentation: `README.md` now states the shipped capability set instead of the
  first milestone, records provenance against logstash-patterns-core (Apache-2.0)
  and lists the commands that verify the claims.
- Documentation: `CHANGELOG.md` gained a versioned section for the first release.

## 0.1.0 - 2026-11-13

- Published to mooncakes.io as `qqq66668/groklite@0.1.0`.
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