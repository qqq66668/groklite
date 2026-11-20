///|
/// The facade hands back the curated registry the patterns compile against.
test "builtin_registry returns the curated set" {
  let registry = @src.builtin_registry()
  assert_eq(registry.size(), 40)
}

///|
/// A known rule expands to a body; an unknown one is an error rather than a crash.
test "resolve_pattern expands a known rule and rejects an unknown one" {
  let registry = @src.builtin_registry()
  match @src.resolve_pattern(registry, "WORD") {
    Ok(body) => assert_eq(body.length() > 0, true)
    Err(error) => abort(@src.describe_registry_error(error))
  }
  match @src.resolve_pattern(registry, "NO_SUCH_RULE") {
    Ok(_) => abort("an unknown rule resolved")
    Err(_) => ()
  }
}

///|
/// The record accessors report what the assembler decided.
test "record accessors agree with the assembled record" {
  let records = @src.assemble(@src.assembler(), ["head", "  tail"])
  assert_eq(records.length(), 1)
  assert_eq(@src.record_line_count(records[0]), 2)
  assert_eq(@src.record_first_line(records[0]), 1)
  assert_eq(@src.record_text(records[0]).length(), 11)
}

///|
/// A truncated reference is a parse error, not a panic.
test "a truncated pattern is a parse error" {
  match @src.parse("%{WORD:name") {
    Ok(_) => abort("a truncated pattern parsed")
    Err(_) => ()
  }
}

///|
/// An empty pattern is answered, whichever way the parser decides.
test "an empty pattern is answered without a panic" {
  match @src.parse("") {
    Ok(_) => ()
    Err(_) => ()
  }
}

///|
/// An unknown rule name is a compile error, not a panic.
test "an unknown rule is a compile error" {
  match @src.compile_builtin("%{NO_SUCH_RULE:x}") {
    Ok(_) => abort("an unknown rule compiled")
    Err(_) => ()
  }
}

///|
/// An oversized line is answered with a result, never with a crash.
test "an oversized line is answered without a panic" {
  let sb : StringBuilder = StringBuilder()
  let mut index = 0
  while index < 300000 {
    sb.write_char('a')
    index = index + 1
  }
  match @src.compile_builtin("%{WORD:w}") {
    Err(_) => abort("the setup pattern did not compile")
    Ok(program) =>
      match @src.match_line(program, sb.to_string()) {
        Ok(_) => ()
        Err(_) => ()
      }
  }
}
