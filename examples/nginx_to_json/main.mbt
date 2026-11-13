///| Turn one access-log line into key=value lines on standard output.
///
/// The output is what continuous integration compares against the README snippet,
/// so the documented result cannot drift away from the real one.
fn main {
  let pattern = "%{IP:client} %{WORD:method} %{STATUS:status}"
  let line = "10.0.0.7 GET 404"
  match @src.compile_builtin(pattern) {
    Err(error) => println("compile error: " + @src.describe_compile_error(error))
    Ok(program) => {
      match @src.match_line(program, line) {
        Err(error) => println("match error: " + @src.describe_match_error(error))
        Ok(fields) => {
          let total = @src.field_total(fields)
          let mut index = 0
          while index < total {
            let name = @src.field_name(fields, index)
            let value = match @src.field_value(fields, name) {
              Some(text) => text
              None => ""
            }
            println(name + "=" + value)
            index = index + 1
          }
        }
      }
    }
  }
}