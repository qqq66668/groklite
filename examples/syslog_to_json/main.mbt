///| Turn one syslog line into key=value lines on standard output.
///
/// Two patterns are compiled and tried in order, which is what a shipper does when a
/// stream mixes formats. The first pattern that matches the whole line wins.
fn main {
  let line = "Jan  5 14:22:01 web-01 sshd panic"
  let syslog_pattern = "%{SYSLOGTIMESTAMP:ts} %{HOST:host} %{PROG:prog} %{WORD:msg}"
  let access_pattern = "%{IP:client} %{WORD:method} %{STATUS:status}"
  match @src.compile_builtin(syslog_pattern) {
    Err(error) => println("compile error: " + @src.describe_compile_error(error))
    Ok(syslog_program) => {
      match @src.compile_builtin(access_pattern) {
        Err(error) => println("compile error: " + @src.describe_compile_error(error))
        Ok(access_program) => {
          let programs = [syslog_program, access_program]
          match @src.match_first(programs, line) {
            Err(error) => println("match error: " + @src.describe_match_error(error))
            Ok(hit) => {
              println("pattern=" + @src.first_pattern_index(hit).to_string())
              let fields = @src.first_fields(hit)
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
  }
}
