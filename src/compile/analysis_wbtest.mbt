///|
fn prog_of(registry : @registry.Registry, text : String) -> Program {
  match compile(registry, text) {
    Ok(program) => program
    Err(error) => abort(describe_compile_error(error))
  }
}

///|
fn with_rule(name : String, body : String) -> (@registry.Registry, String) {
  let registry = @registry.empty()
  registry.add(name, body)
  (registry, "%{" + name + ":value}")
}

///|
test "a literal pattern is bounded on both sides" {
  let report = analyze(prog_of(@registry.builtin(), "hi"))
  assert_eq(report.min_chars(), 2)
  assert_eq(report.max_chars(), Some(2))
  assert_eq(report.structure_steps(), Some(2))
}

///|
test "an unbounded class is unbounded on the maximum side" {
  let report = analyze(prog_of(@registry.builtin(), "%{NUMBER:n}"))
  assert_eq(report.min_chars(), 1)
  assert_eq(report.max_chars(), None)
  assert_eq(report.field_bound(0), None)
}

///|
test "a three-digit status has an exact width" {
  let report = analyze(prog_of(@registry.builtin(), "%{STATUS:s}"))
  assert_eq(report.min_chars(), 3)
  assert_eq(report.max_chars(), Some(3))
  assert_eq(report.field_bound(0), Some(3))
}

///|
test "a bounded repetition sums up" {
  let (registry, text) = with_rule("REP", "a{2,4}")
  let report = analyze(prog_of(registry, text))
  assert_eq(report.min_chars(), 2)
  assert_eq(report.max_chars(), Some(4))
  assert_eq(report.structure_steps(), Some(4))
}

///|
test "alternation takes the widest branch for the maximum" {
  let (registry, text) = with_rule("ALT", "(?:ab|abcd)")
  let report = analyze(prog_of(registry, text))
  assert_eq(report.min_chars(), 2)
  assert_eq(report.max_chars(), Some(4))
}

///|
test "a realistic access-log pattern reports per-field bounds" {
  let report = analyze(
    prog_of(@registry.builtin(), "%{IP:client} %{WORD:method} %{STATUS:status}"),
  )
  assert_eq(report.min_chars(), 13)
  assert_eq(report.max_chars(), None)
  assert_eq(report.field_bound(0), Some(15))
  assert_eq(report.field_bound(1), None)
  assert_eq(report.field_bound(2), Some(3))
}

///|
test "an unbounded repetition over a nullable body is reported" {
  let (registry, text) = with_rule("LOOP", "(?:a?)*")
  let report = analyze(prog_of(registry, text))
  assert_true(report.issue_count() > 0)
  assert_eq(
    describe_issue(report.issue_at(0)),
    "unbounded repetition over a body that can match nothing",
  )
}

///|
test "an end anchor followed by a consumer is reported" {
  let (registry, text) = with_rule("BADEND", "a$b")
  let report = analyze(prog_of(registry, text))
  assert_true(report.issue_count() > 0)
  assert_eq(
    describe_issue(report.issue_at(0)),
    "end anchor at index 1 is followed by a consuming instruction",
  )
}

///|
test "a start anchor after a consumer is reported" {
  let (registry, text) = with_rule("BADSTART", "a^b")
  let report = analyze(prog_of(registry, text))
  assert_true(report.issue_count() > 0)
  assert_eq(
    describe_issue(report.issue_at(0)),
    "start anchor at index 1 follows a consuming instruction",
  )
}

///|
test "a duplicated alternation branch is reported" {
  let (registry, text) = with_rule("DUP", "(?:ab|ab)")
  let report = analyze(prog_of(registry, text))
  assert_true(report.issue_count() > 0)
  assert_eq(
    describe_issue(report.issue_at(0)),
    "alternation branch 1 repeats an earlier branch",
  )
}

///|
test "a clean pattern reports no issues" {
  let report = analyze(
    prog_of(@registry.builtin(), "%{IP:client} %{WORD:method}"),
  )
  assert_eq(report.issue_count(), 0)
}
