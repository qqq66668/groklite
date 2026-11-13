# groklite

> 中文一句话：把非结构化日志行按 grok 风格模式拆成命名字段，纯计算、无 IO、多目标可用。

A log line arrives as text and is wanted as strings keyed by name. Somewhere between
the process that prints it and the store that indexes it, somebody decides which part
of the line is the status code. That decision usually ends up inside a regular
expression the next person cannot read, cannot test, and cannot extend without
breaking three other services.

groklite keeps the decision in one place. A pattern names what to extract:

```
%{IP:client} %{WORD:method} %{NUMBER:status}
```

a registry gives each name a rule, and one call turns a line into fields. Patterns are
data, so adding a format is a table entry with a corpus line behind it, not a new
regular expression in a new service.

## Shape

Four packages with one direction of dependency:

- `src/syntax` turns pattern text into ordered segments and reports offsets.
- `src/registry` maps a pattern name to a rule.
- `src/compile` expands references and lowers them into a matcher program.
- `src/engine` executes that program over one line.

`src` is the only package with public exports. `docs/design.md` states the invariants
and `docs/limits.md` states what the library refuses to do.

## What works today

The pattern syntax layer. `parse` turns pattern text into ordered segments, attaches a
field name to the reference that carries it, and reports malformed input with an
offset and a caret line instead of a boolean. There is no guessing involved: eight
tests cover literals, references with and without a field, mixed patterns, an
unterminated reference, an empty name, an empty field and a character outside the
allowed set.

The registry adds a curated ten-entry built-in subset plus recursive expansion with
cycle, depth and nested-field errors. Matching is not implemented yet. `docs/limits.md` describes the grammar the matcher
will accept, so the boundary is written down before the code exists.

## What is next

1. A registry with a curated subset: access logs, syslog, CEF.
2. Compilation into a program with numbered slots plus a field table.
3. Matching one line and returning a field map.
4. A corpus-driven test package and one runnable example.

## Boundaries

No file input, no network input, no log shipping, no type coercion: a caller hands in
a string and gets a value back. The library is not a drop-in replacement for an
upstream pattern collection and makes no claim of parity with one. Every shipped
pattern carries a corpus line; anything else is not shipped.

## Licence

Apache-2.0. See `LICENSE`.