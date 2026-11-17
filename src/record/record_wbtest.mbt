///|
test "plain lines become one record each" {
  let records = assemble(assembler(), ["a", "b", "c"])
  assert_eq(records.length(), 3)
  assert_eq(records[0].first_line(), 1)
  assert_eq(records[2].first_line(), 3)
  assert_eq(records[1].text(), "b")
}

///|
test "an indented stack frame joins the header" {
  let records = assemble(assembler(), [
    "java.lang.RuntimeException: boom", "    at com.example.Main.run(Main.java:12)",
    "    at com.example.Main.main(Main.java:4)",
  ])
  assert_eq(records.length(), 1)
  assert_eq(records[0].line_count(), 3)
  assert_eq(records[0].first_line(), 1)
}

///|
test "a configured prefix joins the record without indentation" {
  let loader = assembler()
  loader.continue_on("Caused by:")
  let records = assemble(loader, ["first failure", "Caused by: timeout"])
  assert_eq(records.length(), 1)
  assert_eq(records[0].line_count(), 2)
}

///|
test "a blank line closes the open record" {
  let records = assemble(assembler(), ["one", "  detail", "", "two"])
  assert_eq(records.length(), 2)
  assert_eq(records[0].line_count(), 2)
  assert_eq(records[1].first_line(), 4)
}

///|
test "a continuation without a predecessor still becomes a record" {
  let records = assemble(assembler(), ["    orphan frame"])
  assert_eq(records.length(), 1)
  assert_eq(records[0].first_line(), 1)
}

///|
test "an empty input yields no records" {
  let empty : Array[String] = []
  assert_eq(assemble(assembler(), empty).length(), 0)
}

///|
test "record text keeps the physical line break" {
  let records = assemble(assembler(), ["head", "  tail"])
  assert_eq(records[0].text().length(), 11)
  assert_eq(records[0].text(), "head" + "\n" + "  tail")
}

///|
test "indentation can be switched off" {
  let strict = assembler()
  strict.without_indented_continuation()
  let records = assemble(strict, ["head", "  indented but standalone"])
  assert_eq(records.length(), 2)
}

///|
test "a record description names its start line" {
  let records = assemble(assembler(), ["head", "  tail"])
  assert_eq(describe_record(records[0]), "record at line 1 covering 2 line(s)")
}

///|
test "streaming completes a record when the next header arrives" {
  let state = stream(assembler())
  let first : Array[Record] = []
  for record in state.feed("head") {
    first.push(record)
  }
  for record in state.feed("  tail") {
    first.push(record)
  }
  assert_eq(first.length(), 0)
  let done = state.feed("next")
  assert_eq(done.length(), 1)
  assert_eq(done[0].line_count(), 2)
  assert_eq(done[0].first_line(), 1)
}

///|
test "streaming finish flushes the open record" {
  let state = stream(assembler())
  for record in state.feed("head") {
    assert_eq(record.line_count(), -1)
  }
  let done = state.finish()
  assert_eq(done.length(), 1)
  assert_eq(done[0].text(), "head")
}

///|
test "streaming and batch produce the same records" {
  let lines : Array[String] = ["a", "  b", "", "c", "  d", "e"]
  let batch = assemble(assembler(), lines)
  let state = stream(assembler())
  let streamed : Array[Record] = []
  for line in lines {
    for record in state.feed(line) {
      streamed.push(record)
    }
  }
  for record in state.finish() {
    streamed.push(record)
  }
  assert_eq(batch.length(), streamed.length())
  let mut index = 0
  while index < batch.length() {
    assert_eq(batch[index].text(), streamed[index].text())
    assert_eq(batch[index].first_line(), streamed[index].first_line())
    assert_eq(batch[index].line_count(), streamed[index].line_count())
    index = index + 1
  }
}
