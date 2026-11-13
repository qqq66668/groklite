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