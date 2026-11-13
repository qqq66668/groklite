# 0003 Built-in patterns are a curated and audited subset

## Context

Upstream grok ships a large pattern collection. Importing it wholesale is
tempting: it is free coverage. It is also a liability. Such a table accumulates
heritage formats that no user of this ecosystem runs, several entries depend on
constructs a bounded engine does not support, and a copied table gives a false
impression that each entry was verified.

## Decision

Every built-in pattern is written in this repository and carries four parts:

1. a name in upper case, unique within the registry;
2. a two-line header stating what the rule matches and what it deliberately does
   not match;
3. at least one corpus line in `test/testdata` that exercises it;
4. a comment naming the source specification or format when one exists.

Registry families are grouped by source format: access logs, syslog, CEF. A family
is included only when a real corpus line exists for it.

## Consequences

- The library makes no claim of parity with upstream collections. The claim is
  only that every shipped pattern is exercised by a corpus line.
- Adding a pattern is a reviewable change with three parts: rule, header, corpus
  line.
- Patterns that would need unsupported constructs are excluded rather than
  emulated, and the exclusion is recorded in `docs/design.md`.