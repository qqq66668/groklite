///|
fn push_text(sb : StringBuilder, text : String) -> Unit {
  for c in text {
    sb.write_char(c)
  }
}

///|
/// Render one corpus row as name=value pairs joined by a pipe.
///
/// This is the only shape the corpus compares, so a behaviour change shows up as
/// one differing row rather than as an assertion rewritten in place.
fn render_fields(pattern : String, line : String) -> String {
  match @src.compile_builtin(pattern) {
    Err(error) => "compile-error: " + @src.describe_compile_error(error)
    Ok(program) =>
      match @src.match_line(program, line) {
        Err(error) => "match-error: " + @src.describe_match_error(error)
        Ok(fields) => {
          let sb : StringBuilder = StringBuilder()
          let total = @src.field_total(fields)
          let mut index = 0
          while index < total {
            if index > 0 {
              sb.write_char('|')
            }
            let name = @src.field_name(fields, index)
            push_text(sb, name)
            sb.write_char('=')
            let value = match @src.field_value(fields, name) {
              Some(text) => text
              None => ""
            }
            push_text(sb, value)
            index = index + 1
          }
          sb.to_string()
        }
      }
  }
}

///|
test "every corpus row keeps its expected field map" {
  let patterns : Array[String] = [
    "%{IP:client} %{WORD:method} %{STATUS:status}", "%{HOST:host} %{WORD:app} %{NUMBER:pid}",
    "%{IPORHOST:peer}%{SPACE}%{USER:user}", "%{INT:delta}", "%{WORD:a}_%{WORD:b}",
    "%{STATUS:code}", "%{NOPE:x}",
  ]
  let lines : Array[String] = [
    "10.0.0.7 GET 404", "web-01 nginx 4242", "10.9.8.7 deploy", "-17", "x_y", "99",
    "x",
  ]
  let expected : Array[String] = [
    "client=10.0.0.7|method=GET|status=404", "host=web-01|app=nginx|pid=4242", "peer=10.9.8.7|user=deploy",
    "delta=-17", "a=x|b=y", "match-error: line does not match the pattern", "compile-error: registry: unknown pattern: NOPE",
  ]
  let mut index = 0
  while index < patterns.length() {
    assert_eq(render_fields(patterns[index], lines[index]), expected[index])
    index = index + 1
  }
}

///|
test "a partial match never yields half a field table" {
  assert_eq(
    render_fields("%{IP:client} %{WORD:method}", "10.0.0.7"),
    "match-error: line does not match the pattern",
  )
}

///|
test "an unnamed reference leaves the table empty" {
  assert_eq(render_fields("%{SPACE}", "   "), "")
}

///|
test "a step budget failure is reported through the facade" {
  match @src.compile_builtin("%{NUMBER:n}") {
    Err(error) => abort(@src.describe_compile_error(error))
    Ok(program) =>
      match @src.match_line_with_limit(program, "123", 1) {
        Ok(_) => abort("expected the budget to run out")
        Err(error) =>
          assert_eq(
            @src.describe_match_error(error),
            "pattern exceeded the step budget of 1 steps",
          )
      }
  }
}

///|
test "the syslog family reads one rfc3164 prefix" {
  assert_eq(
    render_fields(
      "%{SYSLOGTIMESTAMP:ts} %{HOST:host} %{PROG:prog}", "Jan  5 14:22:01 web-01 sshd",
    ),
    "ts=Jan  5 14:22:01|host=web-01|prog=sshd",
  )
}

///|
test "a composite pattern matches without claiming a slot" {
  assert_eq(
    render_fields(
      "%{SYSLOGBASE} %{WORD:msg}", "Dec 31 23:59:59 db-1 kernel panic",
    ),
    "msg=panic",
  )
}

///|
test "a stream of mixed formats lands on the first pattern that fits" {
  let three = match @src.compile_builtin("%{STATUS:code}") {
    Ok(program) => program
    Err(error) => abort(@src.describe_compile_error(error))
  }
  let plain = match @src.compile_builtin("%{NUMBER:num}") {
    Ok(program) => program
    Err(error) => abort(@src.describe_compile_error(error))
  }
  let programs = [three, plain]
  match @src.match_first(programs, "404") {
    Ok(hit) => {
      assert_eq(@src.first_pattern_index(hit), 0)
      let fields = @src.first_fields(hit)
      assert_eq(@src.field_total(fields), 1)
      assert_eq(@src.field_value(fields, "code"), Some("404"))
    }
    Err(error) => abort(@src.describe_match_error(error))
  }
  match @src.match_first(programs, "42") {
    Ok(hit) => {
      assert_eq(@src.first_pattern_index(hit), 1)
      let fields = @src.first_fields(hit)
      assert_eq(@src.field_value(fields, "num"), Some("42"))
    }
    Err(error) => abort(@src.describe_match_error(error))
  }
}
