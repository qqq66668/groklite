///|
/// How to decide whether a physical line continues the open record.
///
/// The indentation switch lives in a one-element array because struct fields are
/// immutable; the array contents are not.
pub struct Assembler {
  prefixes : Array[String]
  flags : Array[Bool]
}

///|
/// One assembled record.
pub struct Record {
  first_line : Int32
  line_count : Int32
  text : String
}

///|
/// The 1-based line number of the first physical line.
pub fn Record::first_line(self : Record) -> Int32 {
  self.first_line
}

///|
/// How many physical lines the record covers.
pub fn Record::line_count(self : Record) -> Int32 {
  self.line_count
}

///|
/// The record text, physical lines joined with a newline.
pub fn Record::text(self : Record) -> String {
  self.text
}

///|
/// An assembler that treats an indented line as a continuation.
pub fn assembler() -> Assembler {
  { prefixes: [], flags: [true], }
}

///|
/// Treat a line starting with this prefix as a continuation of the open record.
pub fn Assembler::continue_on(self : Assembler, prefix : String) -> Unit {
  self.prefixes.push(prefix)
}

///|
/// Stop treating indentation as a continuation signal.
pub fn Assembler::without_indented_continuation(self : Assembler) -> Unit {
  self.flags[0] = false
}

///|
/// A push-based assembler for streams.
///
/// Mutable state lives in one-element arrays because struct fields are immutable.
pub struct StreamAssembler {
  loader : Assembler
  first : Array[Int32]
  seen : Array[Int32]
  open : Array[Bool]
  buffer : Array[Array[String]]
}

///|
/// Start a stream assembly with the given continuation rules.
pub fn stream(loader : Assembler) -> StreamAssembler {
  { loader, first: [0], seen: [0], open: [false], buffer: [[]], }
}

///|
fn chars_of(text : String) -> Array[Char] {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  chars
}

///|
fn starts_with_at(text : Array[Char], prefix : Array[Char]) -> Bool {
  if prefix.length() > text.length() {
    return false
  }
  let mut index = 0
  let mut same = true
  while index < prefix.length() {
    if text[index] != prefix[index] {
      same = false
    }
    index = index + 1
  }
  same
}

///|
fn starts_with_text(text : String, prefix : String) -> Bool {
  starts_with_at(chars_of(text), chars_of(prefix))
}

///|
fn is_blank(line : String) -> Bool {
  let mut blank = true
  for c in line {
    if c != ' ' && c != '\t' {
      blank = false
    }
  }
  blank
}

///|
fn is_indented(line : String) -> Bool {
  let chars = chars_of(line)
  if chars.length() == 0 {
    return false
  }
  chars[0] == ' ' || chars[0] == '\t'
}

///|
fn is_continuation(loader : Assembler, line : String) -> Bool {
  if loader.flags[0] && is_indented(line) {
    return true
  }
  let mut index = 0
  let mut hit = false
  while index < loader.prefixes.length() {
    if starts_with_text(line, loader.prefixes[index]) {
      hit = true
    }
    index = index + 1
  }
  hit
}

///|
fn close_record(state : StreamAssembler) -> Record {
  let lines = state.buffer[0]
  let sb : StringBuilder = StringBuilder()
  let mut index = 0
  while index < lines.length() {
    if index > 0 {
      sb.write_char('\n')
    }
    sb.write_string(lines[index])
    index = index + 1
  }
  let record : Record = {
    first_line: state.first[0],
    line_count: lines.length(),
    text: sb.to_string(),
  }
  state.open[0] = false
  state.buffer[0] = []
  record
}

///|
/// Feed one physical line; returns the record it completes, if any.
///
/// A blank line closes the open record and is dropped. A continuation joins the open
/// record; with no record open it starts one, so a truncated first line survives.
pub fn StreamAssembler::feed(
  self : StreamAssembler,
  line : String,
) -> Array[Record] {
  self.seen[0] = self.seen[0] + 1
  let finished : Array[Record] = []
  if is_blank(line) {
    if self.open[0] {
      finished.push(close_record(self))
    }
    return finished
  }
  if self.open[0] && is_continuation(self.loader, line) {
    self.buffer[0].push(line)
    return finished
  }
  if self.open[0] {
    finished.push(close_record(self))
  }
  self.first[0] = self.seen[0]
  self.open[0] = true
  self.buffer[0] = [line]
  finished
}

///|
/// Close the open record at the end of a stream.
pub fn StreamAssembler::finish(self : StreamAssembler) -> Array[Record] {
  let finished : Array[Record] = []
  if self.open[0] {
    finished.push(close_record(self))
  }
  finished
}

///|
/// Assemble physical lines into logical records.
///
/// Implemented on top of the streaming assembler, so the batch and the stream cannot
/// drift apart.
pub fn assemble(loader : Assembler, lines : Array[String]) -> Array[Record] {
  let state = stream(loader)
  let records : Array[Record] = []
  for line in lines {
    for record in state.feed(line) {
      records.push(record)
    }
  }
  for record in state.finish() {
    records.push(record)
  }
  records
}

///|
/// Render one record as a stable single line of description.
pub fn describe_record(record : Record) -> String {
  "record at line " +
  record.first_line.to_string() +
  " covering " +
  record.line_count.to_string() +
  " line(s)"
}
