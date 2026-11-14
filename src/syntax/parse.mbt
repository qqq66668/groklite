///|
/// Character classes used by pattern names and field names.
fn is_ascii_digit(c : Char) -> Bool {
  let code = c.to_int()
  code >= 48 && code <= 57
}

///|
fn is_ascii_upper(c : Char) -> Bool {
  let code = c.to_int()
  code >= 65 && code <= 90
}

///|
fn is_ascii_lower(c : Char) -> Bool {
  let code = c.to_int()
  code >= 97 && code <= 122
}

///|
fn is_name_char(c : Char) -> Bool {
  is_ascii_digit(c) || is_ascii_upper(c) || is_ascii_lower(c) || c == '_'
}

///|
/// Parse pattern text into ordered segments.
///
/// `%{NAME}` and `%{NAME:field}` are references; everything else is literal text
/// that must match verbatim. Failures carry the offset the problem was seen at.
pub fn parse(text : String) -> Result[Pattern, ParseError] {
  let segments : Array[Segment] = []
  let mut literal : StringBuilder = StringBuilder()
  let mut name_buf : StringBuilder = StringBuilder()
  let mut field_buf : StringBuilder = StringBuilder()
  let mut literal_len = 0
  let mut name_len = 0
  let mut field_len = 0
  let mut mode = 0
  let mut pending_percent = false
  let mut ref_offset = 0
  let mut colon_offset = 0
  let mut offset = 0
  for c in text {
    if mode == 0 {
      if pending_percent {
        pending_percent = false
        if c == '{' {
          if literal_len > 0 {
            segments.push(Literal(literal.to_string()))
          }
          literal = StringBuilder()
          literal_len = 0
          name_buf = StringBuilder()
          field_buf = StringBuilder()
          name_len = 0
          field_len = 0
          ref_offset = offset - 1
          mode = 1
        } else {
          literal.write_char('%')
          literal_len = literal_len + 1
          if c == '%' {
            pending_percent = true
          } else {
            literal.write_char(c)
            literal_len = literal_len + 1
          }
        }
      } else if c == '%' {
        pending_percent = true
      } else {
        literal.write_char(c)
        literal_len = literal_len + 1
      }
    } else if mode == 1 {
      if c == '}' {
        if name_len == 0 {
          return Err({ kind: EmptyName, offset: ref_offset + 2, source: text, })
        }
        segments.push(Ref({ name: name_buf.to_string(), field: None, }))
        name_buf = StringBuilder()
        name_len = 0
        mode = 0
      } else if c == ':' {
        if name_len == 0 {
          return Err({ kind: EmptyName, offset: ref_offset + 2, source: text, })
        }
        colon_offset = offset
        mode = 2
      } else if is_name_char(c) {
        name_buf.write_char(c)
        name_len = name_len + 1
      } else {
        return Err({ kind: InvalidNameChar, offset, source: text, })
      }
    } else if c == '}' {
      if field_len == 0 {
        return Err({ kind: EmptyField, offset: colon_offset, source: text, })
      }
      segments.push(
        Ref({ name: name_buf.to_string(), field: Some(field_buf.to_string()), }),
      )
      name_buf = StringBuilder()
      field_buf = StringBuilder()
      name_len = 0
      field_len = 0
      mode = 0
    } else if is_name_char(c) {
      field_buf.write_char(c)
      field_len = field_len + 1
    } else {
      return Err({ kind: InvalidFieldChar, offset, source: text, })
    }
    offset = offset + 1
  }
  if mode != 0 {
    return Err({
      kind: UnterminatedReference,
      offset: ref_offset,
      source: text,
    })
  }
  if pending_percent {
    literal.write_char('%')
    literal_len = literal_len + 1
  }
  if literal_len > 0 {
    segments.push(Literal(literal.to_string()))
  }
  Ok({ segments, })
}
