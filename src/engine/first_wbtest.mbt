///|
test "the first program that matches wins" {
  let three = compile_of(@registry.builtin(), "%{STATUS:code}")
  let plain = compile_of(@registry.builtin(), "%{NUMBER:num}")
  let programs : Array[@compile.Program] = [three, plain]
  match match_first(programs, "404") {
    Ok(hit) => {
      assert_eq(hit.first_pattern_index(), 0)
      assert_eq(hit.first_matched_fields().value_at(0), "404")
    }
    Err(error) => abort(describe_match_error(error))
  }
}

///|
test "a later program matches when earlier ones miss" {
  let three = compile_of(@registry.builtin(), "%{STATUS:code}")
  let plain = compile_of(@registry.builtin(), "%{NUMBER:num}")
  let programs : Array[@compile.Program] = [three, plain]
  match match_first(programs, "42") {
    Ok(hit) => {
      assert_eq(hit.first_pattern_index(), 1)
      assert_eq(hit.first_matched_fields().value_at(0), "42")
    }
    Err(error) => abort(describe_match_error(error))
  }
}

///|
test "no program matching is reported once for the whole list" {
  let three = compile_of(@registry.builtin(), "%{STATUS:code}")
  let plain = compile_of(@registry.builtin(), "%{NUMBER:num}")
  let programs : Array[@compile.Program] = [three, plain]
  match match_first(programs, "GET /index") {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(describe_match_error(error), "line does not match the pattern")
  }
}

///|
test "an empty program list matches nothing" {
  let programs : Array[@compile.Program] = []
  match match_first(programs, "anything") {
    Ok(_) => abort("expected no match")
    Err(error) =>
      assert_eq(describe_match_error(error), "line does not match the pattern")
  }
}

///|
test "a budget failure stops the search instead of counting as a miss" {
  let plain = compile_of(@registry.builtin(), "%{NUMBER:num}")
  let programs : Array[@compile.Program] = [plain]
  match match_first_with_limit(programs, "123", 1) {
    Ok(_) => abort("expected the budget to run out")
    Err(error) =>
      assert_eq(
        describe_match_error(error),
        "pattern exceeded the step budget of 1 steps",
      )
  }
}
