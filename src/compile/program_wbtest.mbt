fn expect_compile(registry : @registry.Registry, pattern_text : String) -> Program {
  match compile(registry, pattern_text) {
    Ok(program) => program
    Err(error) => abort(describe_compile_error(error))
  }
}

fn expect_compile_error(registry : @registry.Registry, pattern_text : String) -> CompileError {
  match compile(registry, pattern_text) {
    Ok(_) => abort("expected a compile error for: " + pattern_text)
    Err(error) => error
  }
}

///|
test "literal text compiles to one flat character sequence" {
  let program = expect_compile(@registry.builtin(), "hi")
  assert_eq(program.field_count(), 0)
  assert_eq(render_program(program), "seq(ch(h) ch(i)) fields=[]")
}

///|
test "a named reference becomes a numbered capture" {
  let registry = @registry.empty()
  registry.add("A", "a")
  let program = expect_compile(registry, "x%{A:first}y")
  assert_eq(program.field_count(), 1)
  assert_eq(program.field_at(0), "first")
  assert_eq(render_program(program), "seq(ch(x) cap(0,ch(a)) ch(y)) fields=[first]")
}

///|
test "two fields are numbered in pattern order" {
  let registry = @registry.empty()
  registry.add("A", "a")
  registry.add("B", "b")
  let program = expect_compile(registry, "%{A:one}-%{B:two}")
  assert_eq(program.field_count(), 2)
  assert_eq(program.field_at(0), "one")
  assert_eq(program.field_at(1), "two")
  assert_eq(render_program(program), "seq(cap(0,ch(a)) ch(-) cap(1,ch(b))) fields=[one,two]")
}

///|
test "an unnamed reference matches without claiming a slot" {
  let program = expect_compile(@registry.builtin(), "%{SPACE}")
  assert_eq(program.field_count(), 0)
  assert_eq(render_program(program), "rep(1,inf,ch( )) fields=[]")
}

///|
test "the same field twice is refused at compile time" {
  let registry = @registry.empty()
  registry.add("A", "a")
  let error = expect_compile_error(registry, "%{A:s} %{A:s}")
  assert_eq(describe_compile_error(error), "duplicate field: s")
}

///|
test "an unknown rule is reported through the registry" {
  let error = expect_compile_error(@registry.builtin(), "%{NOPE:x}")
  assert_eq(describe_compile_error(error), "registry: unknown pattern: NOPE")
}

///|
test "a nested field is reported through the registry" {
  let registry = @registry.empty()
  registry.add("OUTER", "%{IP:client}")
  registry.add("IP", "x")
  let error = expect_compile_error(registry, "%{OUTER:y}")
  assert_eq(describe_compile_error(error), "registry: field name on a nested reference at offset 0 is not supported")
}

///|
test "a malformed rule body is reported at its offset" {
  let registry = @registry.empty()
  registry.add("BAD", "[abc")
  let error = expect_compile_error(registry, "%{BAD:x}")
  assert_eq(describe_compile_error(error), "rule: unbalanced character class at offset 0")
}

///|
test "an empty pattern is refused" {
  let error = expect_compile_error(@registry.builtin(), "")
  assert_eq(describe_compile_error(error), "empty pattern")
}

///|
test "malformed pattern text keeps its caret line" {
  let error = expect_compile_error(@registry.builtin(), "%{WORD")
  assert_eq(describe_compile_error(error), "pattern: pattern error at offset 0: unterminated pattern reference\n  %{WORD\n  ^")
}

///|
test "a real access-log pattern compiles with three fields" {
  let program = expect_compile(@registry.builtin(), "%{IP:client} %{WORD:method} %{STATUS:status}")
  assert_eq(program.field_count(), 3)
  assert_eq(program.field_at(0), "client")
  assert_eq(program.field_at(1), "method")
  assert_eq(program.field_at(2), "status")
  assert_true(render_program(program).length() > 20)
}