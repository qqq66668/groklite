///| One step of a small integer generator, so a stress run reproduces from this file

///|
/// alone with no clock and no entropy source involved.
fn stress_step(state : Int32) -> Int32 {
  (state * 31 + 17) % 997
}

///| Build a line from a fixed alphabet, describing both its length and its

///|
/// characters through the generator.
fn stress_line(state : Int32, length : Int32) -> String {
  let alphabet = "ab01.: -_"
  let chars : Array[Char] = []
  for c in alphabet {
    chars.push(c)
  }
  let sb : StringBuilder = StringBuilder()
  let mut seed = state
  let mut index = 0
  while index < length {
    seed = stress_step(seed)
    sb.write_char(chars[seed % chars.length()])
    index = index + 1
  }
  sb.to_string()
}

///|
fn stress_program(pattern_text : String) -> @compile.Program {
  match @compile.compile(@registry.builtin(), pattern_text) {
    Ok(program) => program
    Err(error) => abort(@compile.describe_compile_error(error))
  }
}

///|
/// Generated input must terminate with exactly one outcome per case: a full match or
/// a reported failure. A panic, a hang or a partial table would break the count.
test "generated input yields exactly one outcome per case" {
  let patterns : Array[String] = [
    "%{IP:client} %{WORD:method} %{STATUS:status}", "%{NUMBER:left}-%{NUMBER:right}",
    "%{NOTSPACE:token}", "%{INT:value}%{SPACE}%{WORD:unit}",
  ]
  let cases_per_pattern = 40
  let mut matched = 0
  let mut failed = 0
  let mut pattern_index = 0
  while pattern_index < patterns.length() {
    let program = stress_program(patterns[pattern_index])
    let mut seed = 7 + pattern_index
    let mut case_index = 0
    while case_index < cases_per_pattern {
      seed = stress_step(seed)
      let line = stress_line(seed, seed % 12)
      match match_line_with_limit(program, line, 20000) {
        Ok(_) => matched = matched + 1
        Err(_) => failed = failed + 1
      }
      case_index = case_index + 1
    }
    pattern_index = pattern_index + 1
  }
  assert_eq(matched + failed, cases_per_pattern * patterns.length())
}
