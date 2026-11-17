# 0005 Assemble records with one push-based state machine

## Context

Record assembly was written first as a batch function over an array of lines. A log
pipeline does not hold its input in memory: lines arrive from a socket, a tail, or a
decoder, and a 10 GB file will never fit. A batch-only API therefore contradicts the
positioning of the stage it implements.

Two shapes were possible. The first is a second, independent streaming implementation;
it is easy to write and easy to let drift, and then the batch and the stream disagree on
trailing records, which is the case that matters. The second is one state machine with
the batch entry point expressed on top of it.

## Decision

One `StreamAssembler` holds the open record and is advanced by `feed`. `finish` flushes
it. The batch `assemble` is implemented by feeding every line and then calling `finish`,
so the two paths are the same code and cannot diverge.

Mutable state lives in one-element arrays because struct fields are immutable; the
alternatives were a global mutable binding, which the target set does not support
uniformly, or a rebuilt struct per line, which allocates on every line of every log.

## Consequences

- A caller with a stream uses `feed`/`finish`; a caller with a slice uses `assemble`.
- A test compares both paths record by record, so a future change to one is a build
  failure rather than a silent difference.
- A record that never ends grows without bound; that is stated in `docs/limits.md` and
  is a property of the input, not of the library.
