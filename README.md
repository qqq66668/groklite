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

## Demo

One recording, captured from a real run of both examples:

![Both examples in one run](docs/demo.gif)

The first block reads an access-log line; the second reads a syslog line with the
syslog family. Nothing in the recording is typed by hand.

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

The registry adds a curated sixteen-entry built-in subset plus recursive expansion with
cycle, depth and nested-field errors. The syslog family then adds month day, time, timestamp, program and a composite base rule, each exercised by a corpus row. The rule grammar reads bracket classes, shorthand escapes, groups, alternation,
anchors and bounded repetition into a node tree, with every malformed body refused at
the offset that caused it. Compilation turns that tree plus the registry into a program with numbered capture
slots and a field table, refusing an unknown rule, a malformed rule body, a field
declared twice and an empty pattern. Matching runs that program over one line and returns a field table keyed by the names the pattern declares. A line must match in full; a partial match is a failure, not a best-effort result. Every pass is bounded by a step budget, and running out is reported as an error rather than a hang. `docs/limits.md` describes the grammar the matcher
will accept, so the boundary is written down before the code exists.

## Run the example

```
moon run examples/nginx_to_json
```

It prints the three fields of one access-log line:

```
client=10.0.0.7
method=GET
status=404
```

The same example runs in continuous integration, so this snippet is verified output, not
a claim. `src/corpus_test.mbt` is the black-box test file: it drives the public facade from a corpus
table of input line plus expected field map.

A stream normally mixes formats, so `match_first` takes compiled programs in order and
returns the first that matches the whole line, or one failure for the whole list. A step
budget failure stops the search instead of being read as a miss.
## A second format

A stream rarely carries one format. `examples/syslog_to_json` compiles two patterns and
tries them in order, printing the fields of the first one that matches the whole line:

```
moon run examples/syslog_to_json
```

```
pattern=0
ts=Jan  5 14:22:01
host=web-01
prog=sshd
msg=panic
```

Both examples run in continuous integration.

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