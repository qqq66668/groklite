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
/// Assemble physical lines into logical records.
///
/// A blank line closes the open record and is dropped. A line that looks like a
/// continuation joins the open record; when no record is open it starts one, so a
/// truncated first line is reported rather than silently discarded.
pub fn assemble(loader : Assembler, lines : Array[String]) -> Array[Record] {
  let records : Array[Record] = []
  let mut open_first : Int32 = 0
  let mut open_count : Int32 = 0
  let mut open_text : StringBuilder = StringBuilder()
  let mut open = false
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    let line_number = index + 1
    if is_blank(line) {
      if open {
        records.push({
          first_line: open_first,
          line_count: open_count,
          text: open_text.to_string(),
        })
        open = false
        open_text = StringBuilder()
        open_count = 0
      }
    } else if open && is_continuation(loader, line) {
      open_text.write_char('\n')
      open_text.write_string(line)
      open_count = open_count + 1
    } else {
      if open {
        records.push({
          first_line: open_first,
          line_count: open_count,
          text: open_text.to_string(),
        })
      }
      open_first = line_number
      open_count = 1
      open = true
      open_text = StringBuilder()
      open_text.write_string(line)
    }
    index = index + 1
  }
  if open {
    records.push({
      first_line: open_first,
      line_count: open_count,
      text: open_text.to_string(),
    })
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
