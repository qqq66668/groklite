///|
/// Show the four stages on one input: assemble, analyse, match, validate.
///
/// The output is deterministic, and continuous integration runs this program, so
/// the documented behaviour cannot drift away from the code.
fn main {
  let lines : Array[String] = [
    "ERROR parse_failed", "    at parser.mbt:12", "", "WARN slow_query 1500",
  ]
  let records = @src.assemble(@src.assembler(), lines)
  println("records=" + records.length().to_string())
  let mut index = 0
  while index < records.length() {
    let record = records[index]
    println(
      "record " +
      (index + 1).to_string() +
      " lines=" +
      @src.record_line_count(record).to_string() +
      " first=" +
      @src.record_first_line(record).to_string(),
    )
    index = index + 1
  }
  let pattern = "%{WORD:level} %{WORD:event} %{NUMBER:ms}"
  match @src.compile_builtin(pattern) {
    Err(_) => println("compile failed")
    Ok(program) => {
      let report = @src.analyze(program)
      let hi = match report.max_chars() {
        Some(value) => value.to_string()
        None => "unbounded"
      }
      println(
        "bounds min=" +
        report.min_chars().to_string() +
        " max=" +
        hi +
        " issues=" +
        report.issue_count().to_string(),
      )
      let spec = @src.contract()
      spec.one_of("level", ["ERROR", "WARN", "INFO"])
      spec.between("ms", 0, 1000)
      let mut r = 0
      while r < records.length() {
        let header = lines[@src.record_first_line(records[r]) - 1]
        match @src.match_line(program, header) {
          Err(_) => println("record " + (r + 1).to_string() + " match=failed")
          Ok(fields) => {
            let mut parts = ""
            let mut i = 0
            while i < @src.field_total(fields) {
              let name = @src.field_name(fields, i)
              let value = match @src.field_value(fields, name) {
                Some(text) => text
                None => ""
              }
              parts = parts + name + "=" + value + " "
              i = i + 1
            }
            println("record " + (r + 1).to_string() + " fields " + parts)
            let problems = @src.validate(fields, spec)
            let mut p = 0
            while p < problems.length() {
              println(
                "record " +
                (r + 1).to_string() +
                " violation " +
                @src.describe_violation(problems[p]),
              )
              p = p + 1
            }
          }
        }
        r = r + 1
      }
    }
  }
}
