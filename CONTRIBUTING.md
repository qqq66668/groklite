# Contributing

## Adding a built-in pattern

A pattern is data plus a corpus row. Four steps, in this order.

1. Add the rule in `src/registry/builtin.mbt` with `registry.add("NAME", "...")`.
   The body must stay inside the grammar described in `docs/limits.md`; a construct
   outside that grammar is refused at compile time rather than emulated.
2. Put a comment above the entry naming what it matches and what it deliberately
   does not match. A rule that cannot state its own boundary does not ship.
3. Add a corpus row in `src/corpus_test.mbt`: an input line, and the field map it
   must produce. Use a line copied from a real log. A row that only restates the
   pattern proves nothing.
4. Run the commands below. A change that moves the field map of an existing row is
   a breaking change, not a contribution.

```
moon fmt && git diff --quiet
moon check --deny-warn
moon test
bash tools/check_no_pii.sh
```

## Where a test belongs

Tests sit beside the package they test. A `*_wbtest.mbt` file is a white-box test of
that package; a `*_test.mbt` file is a black-box test of its public surface. The
corpus file `src/corpus_test.mbt` is the black-box test of the facade, and a
behaviour change belongs there, so the diff shows a changed expectation instead of a
rewritten assertion.

## Reporting a defect

A useful report carries four things: the pattern text, the input line, what came out
and what was expected. For a compile failure the offset in the error message belongs
in the report as well; it is what makes a pattern bug reproducible without guessing.
