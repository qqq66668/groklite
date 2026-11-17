# 0004 Put the depth after the match, not inside it

## Context

An early version claimed its difference against general regular-expression
libraries in four capabilities: whole-line matching, capture groups, error positions
and a step budget. Each of those is what a matcher already provides, and the
ecosystem has working engines that advertise bounded work. Measured against them,
the project was a thin wrapper: the pattern syntax, the expansion and the slot table
were real work but not a distinct core.

Review feedback said the same thing in one sentence: after subtracting the reusable
capabilities, not enough independent depth remained.

## Decision

The matching layer stays, but it is positioned as infrastructure rather than as the
contribution. Depth moves to three stages a matcher cannot supply, because each one
needs information a compiled matcher does not expose:

1. `analysis` walks the instruction tree. A regular-expression binding hands over a
   compiled object; the tree is not yours to inspect. Length bounds, a structural
   step count and four pattern defects are only computable with the tree.
2. `contract` validates field values after the match. Matching answers "does the text
   have this shape"; it cannot answer "is this status a real status, is this byte
   count non-negative, is the end after the start".
3. `record` decides where a record begins and ends. A line-oriented matcher works on
   lines; a log record is often several of them.

## Consequences

- The README leads with the pipeline, not with the matcher.
- Each stage is optional and independent, so a caller can use the matcher alone.
- Claims about bounds are stated precisely: `structure_steps` counts tree visits and
   is explicitly not a budget for the engine.
- Numeric parsing rejects values that do not fit 32 bits instead of wrapping, because
   a wrapped value would silently satisfy a range check.
