///|
fn fields_of(pattern : String, line : String) -> @engine.Fields {
  match @engine.compile_builtin(pattern) {
    Err(_) => abort("compile failed for " + pattern)
    Ok(program) =>
      match @engine.match_line(program, line) {
        Err(_) => abort("match failed for " + line)
        Ok(fields) => fields
      }
  }
}

///|
fn messages(violations : Array[Violation]) -> Array[String] {
  let out : Array[String] = []
  for violation in violations {
    out.push(describe_violation(violation))
  }
  out
}

///|
test "a required field that is absent is reported" {
  let spec = contract()
  spec.require("status")
  let found = validate(fields_of("%{WORD:method}", "GET"), spec)
  assert_eq(found.length(), 1)
  assert_eq(describe_violation(found[0]), "missing required field: status")
}

///|
test "a clean contract reports nothing" {
  let spec = contract()
  spec.require("status")
  spec.between("status", 100, 599)
  assert_eq(validate(fields_of("%{STATUS:status}", "404"), spec).length(), 0)
}

///|
test "an out-of-range status is reported with the range" {
  let spec = contract()
  spec.between("status", 100, 599)
  let found = validate(fields_of("%{STATUS:status}", "999"), spec)
  assert_eq(
    describe_violation(found[0]),
    "field status is out of range 100..599: 999",
  )
}

///|
test "a non-integer value is reported as such, not as out of range" {
  let spec = contract()
  spec.between("code", 1, 9)
  let found = validate(fields_of("%{WORD:code}", "OK"), spec)
  assert_eq(found.length(), 1)
  assert_eq(describe_violation(found[0]), "field code is not an integer: OK")
}

///|
test "an enum rejects a value outside the set" {
  let spec = contract()
  spec.one_of("method", ["GET", "POST", "PUT", "DELETE"])
  let found = validate(fields_of("%{WORD:method}", "TRACE"), spec)
  assert_eq(
    describe_violation(found[0]),
    "field method is not one of the allowed values: TRACE",
  )
}

///|
test "length bounds are enforced on both sides" {
  let spec = contract()
  spec.min_length("token", 5)
  spec.max_length("token", 1)
  let found = messages(validate(fields_of("%{WORD:token}", "ab"), spec))
  assert_eq(found.length(), 2)
  assert_eq(found[0], "field token is shorter than 5: ab")
  assert_eq(found[1], "field token is longer than 1: ab")
}

///|
test "a cross-field comparison passes when the order holds" {
  let spec = contract()
  spec.greater_or_equal("stop", "start")
  assert_eq(
    validate(fields_of("%{NUMBER:start}-%{NUMBER:stop}", "5-9"), spec).length(),
    0,
  )
}

///|
test "a cross-field comparison fails when the order is inverted" {
  let spec = contract()
  spec.greater_or_equal("stop", "start")
  let found = validate(fields_of("%{NUMBER:start}-%{NUMBER:stop}", "9-5"), spec)
  assert_eq(
    describe_violation(found[0]),
    "field stop (5) must be at least field start (9)",
  )
}

///|
test "several declared fields accumulate their violations in order" {
  let spec = contract()
  spec.between("status", 100, 599)
  spec.one_of("method", ["POST"])
  spec.min_length("client", 20)
  let found = messages(
    validate(
      fields_of(
        "%{IP:client} %{WORD:method} %{STATUS:status}", "10.0.0.7 GET 999",
      ),
      spec,
    ),
  )
  assert_eq(found.length(), 3)
  assert_eq(found[0], "field status is out of range 100..599: 999")
  assert_eq(found[1], "field method is not one of the allowed values: GET")
  assert_eq(found[2], "field client is shorter than 20: 10.0.0.7")
}

///|
test "a negative byte count violates a non-negative range" {
  let spec = contract()
  spec.between("bytes", 0, 2147483647)
  let found = validate(fields_of("%{INT:bytes}", "-5"), spec)
  assert_eq(
    describe_violation(found[0]),
    "field bytes is out of range 0..2147483647: -5",
  )
}

///|
test "an optional field that is absent is skipped silently" {
  let spec = contract()
  spec.min_length("absent", 10)
  assert_eq(validate(fields_of("%{WORD:method}", "GET"), spec).length(), 0)
}

///|
test "a value beyond 32 bits is rejected instead of wrapping" {
  let spec = contract()
  spec.between("bytes", 0, 100)
  let found = validate(fields_of("%{NUMBER:bytes}", "4294967306"), spec)
  assert_eq(found.length(), 1)
  assert_eq(
    describe_violation(found[0]),
    "field bytes does not fit a 32-bit integer: 4294967306",
  )
}

///|
test "a moderately large value still parses" {
  let spec = contract()
  spec.between("bytes", 0, 2147483647)
  assert_eq(
    validate(fields_of("%{NUMBER:bytes}", "2147483647"), spec).length(),
    0,
  )
}
