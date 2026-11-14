///|
/// Why a pattern could not be parsed.
pub enum ParseErrorKind {
  UnterminatedReference
  EmptyName
  InvalidNameChar
  EmptyField
  InvalidFieldChar
}

///|
/// A parse failure: what went wrong, where, and the text it came from.
pub struct ParseError {
  kind : ParseErrorKind
  offset : Int32
  source : String
}

///|
fn headline(kind : ParseErrorKind) -> String {
  match kind {
    UnterminatedReference => "unterminated pattern reference"
    EmptyName => "empty pattern name"
    InvalidNameChar => "pattern name contains a character outside A-Z a-z 0-9 _"
    EmptyField => "empty field name"
    InvalidFieldChar => "field name contains a character outside A-Z a-z 0-9 _"
  }
}

///|
/// Render a parse failure as a headline and a caret line at the offset.
pub fn describe_error(error : ParseError) -> String {
  let mut indent = ""
  let mut index = 0
  while index < error.offset {
    indent = indent + " "
    index = index + 1
  }
  "pattern error at offset " +
  error.offset.to_string() +
  ": " +
  headline(error.kind) +
  "\n" +
  "  " +
  error.source +
  "\n" +
  "  " +
  indent +
  "^"
}
