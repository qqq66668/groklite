///|
fn backslash_text() -> String {
  let sb : StringBuilder = StringBuilder()
  sb.write_char('\\')
  sb.to_string()
}

///|
fn compile_of(
  registry : @registry.Registry,
  pattern_text : String,
) -> @compile.Program {
  match @compile.compile(registry, pattern_text) {
    Ok(program) => program
    Err(error) => abort(@compile.describe_compile_error(error))
  }
}

///|
fn expect_match(program : @compile.Program, line : String) -> Fields {
  match match_line(program, line) {
    Ok(fields) => fields
    Err(error) => abort(describe_match_error(error))
  }
}

///|
test "a literal pattern must consume the whole line" {
  let program = compile_of(@registry.builtin(), "hi")
  assert_eq(expect_match(program, "hi").size(), 0)
  match match_line(program, "ho") {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(describe_match_error(error), "line does not match the pattern")
  }
}

///|
test "a named word becomes a field" {
  let program = compile_of(@registry.builtin(), "%{WORD:word}")
  let fields = expect_match(program, "hello")
  assert_eq(fields.size(), 1)
  assert_eq(fields.name_at(0), "word")
  assert_eq(fields.value_at(0), "hello")
}

///|
test "a greedy repetition captures as much as it can" {
  let program = compile_of(@registry.builtin(), "%{NUMBER:digits}")
  assert_eq(expect_match(program, "12345").value_at(0), "12345")
}

///|
test "two fields keep pattern order" {
  let program = compile_of(@registry.builtin(), "%{WORD:left}_%{NUMBER:right}")
  let fields = expect_match(program, "abc_42")
  assert_eq(fields.name_at(0), "left")
  assert_eq(fields.value_at(0), "abc")
  assert_eq(fields.name_at(1), "right")
  assert_eq(fields.value_at(1), "42")
}

///|
test "a three-digit class accepts exactly three digits" {
  let program = compile_of(@registry.builtin(), "%{STATUS:code}")
  assert_eq(expect_match(program, "404").value_at(0), "404")
  match match_line(program, "40") {
    Ok(_) => abort("expected no match for two digits")
    Err(_) => ()
  }
}

///|
test "an ip class accepts dotted quads only" {
  let program = compile_of(@registry.builtin(), "%{IP:client}")
  assert_eq(expect_match(program, "10.0.0.1").value_at(0), "10.0.0.1")
  match match_line(program, "10.0.0") {
    Ok(_) => abort("expected no match for three octets")
    Err(_) => ()
  }
}

///|
test "alternation picks the branch that fits the rest of the line" {
  let registry = @registry.empty()
  registry.add("ANIMAL", "(?:cat|dog)")
  let program = compile_of(registry, "%{ANIMAL:pet}")
  assert_eq(expect_match(program, "dog").value_at(0), "dog")
}

///|
test "a negated class stops at the excluded character" {
  let program = compile_of(@registry.builtin(), "%{NOTSPACE:token}")
  assert_eq(expect_match(program, "abc").value_at(0), "abc")
  match match_line(program, "a b") {
    Ok(_) => abort("expected no match when a space appears")
    Err(_) => ()
  }
}

///|
test "an unknown field name has no value" {
  let program = compile_of(@registry.builtin(), "%{WORD:word}")
  let fields = expect_match(program, "hello")
  match fields.get("absent") {
    None => ()
    Some(value) => abort("expected no value, got " + value)
  }
  assert_eq(fields.has("word"), true)
  assert_eq(fields.has("absent"), false)
}

///|
test "a shorthand class matches a digit run" {
  let registry = @registry.empty()
  registry.add("DIGITS", backslash_text() + "d+")
  let program = compile_of(registry, "%{DIGITS:num}")
  assert_eq(expect_match(program, "2026").value_at(0), "2026")
}

///|
test "a tiny step budget is reported rather than ignored" {
  let program = compile_of(@registry.builtin(), "%{NUMBER:n}")
  match match_line_with_limit(program, "123", 1) {
    Ok(_) => abort("expected the budget to run out")
    Err(error) =>
      assert_eq(
        describe_match_error(error),
        "pattern exceeded the step budget of 1 steps",
      )
  }
}

///|
test "a realistic access-log line fills three fields" {
  let program = compile_of(
    @registry.builtin(),
    "%{IP:client} %{WORD:method} %{STATUS:status}",
  )
  let fields = expect_match(program, "10.1.2.3 GET 200")
  assert_eq(fields.value_at(0), "10.1.2.3")
  assert_eq(fields.value_at(1), "GET")
  assert_eq(fields.value_at(2), "200")
}

///|
test "a failure reports the position it reached and the instruction it was trying" {
  match match_line(compile_of(@registry.builtin(), "hi"), "ho") {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(
        describe_failure(error),
        "no match: reached position 1 of 2 while trying ch(i)",
      )
  }
}

///|
test "a failure at the first character names the class" {
  match match_line(compile_of(@registry.builtin(), "%{NUMBER:n}"), "abc") {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(
        describe_failure(error),
        "no match: reached position 0 of 3 while trying cap(0,rep(1,inf,cls(0-9)))",
      )
  }
}

///|
test "a failure at the end of the line reports the full length" {
  match
    match_line(
      compile_of(@registry.builtin(), "%{IP:c} %{WORD:m} %{STATUS:s}"),
      "10.0.0.7 GET 40",
    ) {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(
        describe_failure(error),
        "no match: reached position 15 of 15 while trying cls(0-9)",
      )
  }
}
