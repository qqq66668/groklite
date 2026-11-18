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

///|
test "every new builtin rule compiles and matches its sample" {
  let cases : Array[(String, String)] = [
    ("DATA", "anything at all"),
    ("GREEDYDATA", "a b c"),
    ("QS", "\"hello world\""),
    ("QUOTEDSTRING", "\"x\""),
    ("POSINT", "42"),
    ("BASE10NUM", "-12.5"),
    ("FLOAT", "-3.14"),
    ("BASE16NUM", "0x1F"),
    ("IPV4", "192.168.1.1"),
    ("IPV6", "::1"),
    ("HOSTNAME", "web-01"),
    ("HOSTPORT", "web-01:8080"),
    ("URIPATH", "/api/v1/users"),
    ("TIMESTAMP_ISO8601", "2026-11-18T10:50:03"),
    ("YEAR", "2026"),
    ("DAY", "Mon"),
    ("MONTHNUM", "12"),
    ("HTTPDATE", "18/Nov/2026:10:50:03"),
    ("LOGLEVEL", "ERROR"),
    ("UUID", "550e8400-e29b-41d4-a716-446655440000"),
    ("MAC", "00:1A:2B:3C:4D:5E"),
    ("EMAILADDRESS", "a.b+c@example.com"),
    ("TZ", "+08:00"),
    ("SYSLOGHOST", "web-01"),
  ]
  let mut index = 0
  while index < cases.length() {
    let pair = cases[index]
    let pattern = "%{" + pair.0 + ":v}"
    match @src.compile_builtin(pattern) {
      Err(_) => abort("rule does not compile: " + pair.0)
      Ok(program) =>
        match @src.match_line(program, pair.1) {
          Err(_) =>
            abort("rule does not match its sample: " + pair.0 + ": " + pair.1)
          Ok(fields) => assert_eq(@src.field_value(fields, "v"), Some(pair.1))
        }
    }
    index = index + 1
  }
}
