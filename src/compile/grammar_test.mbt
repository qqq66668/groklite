///|
fn backslash_text() -> String {
  let sb : StringBuilder = StringBuilder()
  sb.write_char('\\')
  sb.to_string()
}

///|
fn expect_rule(text : String) -> @compile.Node {
  match @compile.parse_rule(text) {
    Ok(node) => node
    Err(error) => abort(@compile.describe_rule_error(error))
  }
}

///|
fn expect_rule_error(text : String) -> @compile.RuleError {
  match @compile.parse_rule(text) {
    Ok(_) => abort("expected a rule error for: " + text)
    Err(error) => error
  }
}

///|
test "a literal run becomes one sequence" {
  assert_eq(
    @compile.render_node(expect_rule("abc")),
    "seq(lit(a) lit(b) lit(c))",
  )
}

///|
test "a bracket class with a bounded repeat" {
  assert_eq(@compile.render_node(expect_rule("[0-9]{3}")), "rep(3,3,cls(0-9))")
}

///|
test "alternation inside a group" {
  assert_eq(
    @compile.render_node(expect_rule("(?:a|b)+")),
    "rep(1,inf,alt(lit(a)|lit(b)))",
  )
}

///|
test "a negated class keeps the space it excludes" {
  assert_eq(@compile.render_node(expect_rule("[^ ]+")), "rep(1,inf,cls(^ ))")
}

///|
test "a shorthand escape stays a shorthand" {
  assert_eq(
    @compile.render_node(expect_rule(backslash_text() + "d+")),
    "rep(1,inf,bs(d))",
  )
}

///|
test "a dot matches any single character" {
  assert_eq(@compile.render_node(expect_rule(".*")), "rep(0,inf,any)")
}

///|
test "anchors sit in the sequence they belong to" {
  assert_eq(@compile.render_node(expect_rule("^a$")), "seq(^ lit(a) $)")
}

///|
test "an unclosed class is an error at its opening bracket" {
  let error = expect_rule_error("[0-9")
  assert_eq(
    @compile.describe_rule_error(error),
    "unbalanced character class at offset 0",
  )
}

///|
test "a quantifier with nothing before it is an error" {
  let error = expect_rule_error("*a")
  assert_eq(
    @compile.describe_rule_error(error),
    "nothing to repeat at offset 0",
  )
}

///|
test "an unclosed group is an error at its opening parenthesis" {
  let error = expect_rule_error("(?:a")
  assert_eq(@compile.describe_rule_error(error), "unbalanced group at offset 0")
}

///|
test "a malformed repetition is an error at the brace" {
  let error = expect_rule_error("a{3")
  assert_eq(
    @compile.describe_rule_error(error),
    "malformed repetition at offset 1",
  )
}

///|
test "a trailing escape is an error at the backslash" {
  let error = expect_rule_error("a" + backslash_text())
  assert_eq(@compile.describe_rule_error(error), "trailing escape at offset 1")
}

///|
test "an empty rule body is refused" {
  let error = expect_rule_error("")
  assert_eq(@compile.describe_rule_error(error), "empty rule body at offset 0")
}
