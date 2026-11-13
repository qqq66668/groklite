fn expect_pattern(text : String) -> @syntax.Pattern {
  match @syntax.parse(text) {
    Ok(pattern) => pattern
    Err(error) => abort("unexpected pattern error: " + @syntax.describe_error(error))
  }
}

fn expect_error(text : String) -> @syntax.ParseError {
  match @syntax.parse(text) {
    Ok(_) => abort("expected a pattern error for: " + text)
    Err(error) => error
  }
}

///|
test "literal text only" {
  let pattern = expect_pattern("hello world")
  assert_eq(pattern.segment_count(), 1)
  assert_eq(@syntax.render_pattern(pattern), "literal(hello world)")
}

///|
test "reference with a field" {
  let pattern = expect_pattern("%{IP:client}")
  assert_eq(pattern.segment_count(), 1)
  assert_eq(@syntax.render_pattern(pattern), "ref(IP:client)")
}

///|
test "reference without a field" {
  assert_eq(@syntax.render_pattern(expect_pattern("%{SPACE}")), "ref(SPACE)")
}

///|
test "literals and references keep their order" {
  let pattern = expect_pattern("from %{IP:client} took %{NUMBER:ms}ms")
  assert_eq(pattern.segment_count(), 5)
  assert_eq(@syntax.render_pattern(pattern), "literal(from ) ref(IP:client) literal( took ) ref(NUMBER:ms) literal(ms)")
}

///|
test "unterminated reference points at its start" {
  let error = expect_error("%{WORD")
  assert_eq(@syntax.describe_error(error), "pattern error at offset 0: unterminated pattern reference\n  %{WORD\n  ^")
}

///|
test "empty name points inside the braces" {
  let error = expect_error("%{}")
  assert_eq(@syntax.describe_error(error), "pattern error at offset 2: empty pattern name\n  %{}\n    ^")
}

///|
test "empty field points at the colon" {
  let error = expect_error("%{IP:}")
  assert_eq(@syntax.describe_error(error), "pattern error at offset 4: empty field name\n  %{IP:}\n      ^")
}

///|
test "a character outside the name set is reported where it appears" {
  let error = expect_error("%{LIVES-9}")
  assert_eq(@syntax.describe_error(error), "pattern error at offset 7: pattern name contains a character outside A-Z a-z 0-9 _\n  %{LIVES-9}\n         ^")
}