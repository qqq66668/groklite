# Task entry points. Every recipe calls the toolchain directly; just only saves typing.
set shell := ["bash", "-uc"]

default:
    @just --list

# Type-check every package, treating warnings as errors.
check:
    moon check --deny-warn

# Build every target declared by the packages.
build:
    moon build

# Run the whole test suite.
test:
    moon test

# Refuse machine paths, personal identifiers and credentials in tracked files.
hygiene:
    bash tools/check_no_pii.sh

# What continuous integration runs, in the same order.
verify: hygiene fmt
    moon check --deny-warn
    moon build
    moon test
# Refuse formatting drift: rewrite sources, then fail if anything moved.
fmt:
    moon fmt
    git diff --exit-code
