# 0002 Keep machine and personal data out of the repository

## Context

A public repository accumulates identifiers without anyone deciding to publish them:
an absolute path copied from a terminal, an author name baked into a manifest, a phone
number in a test fixture, a token pasted while debugging. Removing them after the first
push does not remove them from history, and rewriting the history of a repository other
people may have cloned is worse than never adding them.

## Decision

1. The commit identity is the account handle and its GitHub noreply address. Real name
   and contact details belong in the submission document, not in the commit log.
2. `tools/check_no_pii.sh` fails the run when a tracked file contains an absolute
   machine path, a digit run of eleven or more, an email address other than the noreply
   form, a token or a private key block.
3. Project-specific terms live in `.pii-blocklist`, which git ignores. The gate reads
   it when present, so the repository never carries the strings the gate looks for.
4. Continuous integration runs the gate before build and test, so a leak fails the
   build instead of relying on review.

## Consequences

- The gate is heuristic. It catches the mechanical cases, which are the ones that
  actually happen.
- Contributors with an unusual address must use the noreply form as well.
- `git log` shows a handle rather than a person; provenance of a submission is carried
  by the submission document.