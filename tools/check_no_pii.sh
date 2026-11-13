#!/usr/bin/env bash
# Repository hygiene gate.
#
# Rejects tracked content that carries machine-specific paths, personal identifiers or
# credentials. Project-specific terms belong in .pii-blocklist, which git ignores, so
# the gate never introduces the strings it is meant to catch.
#
# Usage: bash tools/check_no_pii.sh

set -euo pipefail

cd "$(dirname "$0")/.."

status=0

scan() {
  label=$1
  pattern=$2
  hits=$(git grep -nIE -- "$pattern" || true)
  if [ -n "$hits" ]; then
    echo "hygiene: $label" >&2
    echo "$hits" >&2
    echo >&2
    status=1
  fi
}

scan_fixed() {
  label=$1
  term=$2
  hits=$(git grep -nIF -- "$term" || true)
  if [ -n "$hits" ]; then
    echo "hygiene: $label" >&2
    echo "$hits" >&2
    echo >&2
    status=1
  fi
}

scan 'absolute Windows path' '[A-Za-z]:[\/](Users|Documents|Desktop|AppData|projects|workspace)'
scan 'absolute POSIX home path' '/(home|Users)/[A-Za-z0-9._-]+/'
scan 'long digit run' '[0-9]{11,}'
scan 'GitHub token' 'gh[pousr]_[A-Za-z0-9]{20,}'
scan 'AWS access key' 'AKIA[0-9A-Z]{16}'
scan 'private key block' 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'

emails=$(git grep -nIE -- '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}' || true)
if [ -n "$emails" ]; then
  unexpected=$(printf '%s' "$emails" | grep -vF 'users.noreply.github.com' || true)
  if [ -n "$unexpected" ]; then
    echo 'hygiene: hard-coded email address' >&2
    echo "$unexpected" >&2
    echo >&2
    status=1
  fi
fi

if [ -f .pii-blocklist ]; then
  while IFS= read -r term; do
    case "$term" in
      '' | '#'*) continue ;;
    esac
    scan_fixed 'blocklist entry' "$term"
  done < .pii-blocklist
fi

if [ "$status" -eq 0 ]; then
  echo 'hygiene: clean'
fi
exit "$status"