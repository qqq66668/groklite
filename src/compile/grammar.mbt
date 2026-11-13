///| One element inside a bracket class.
pub enum ClassItem {
  Single(Char)
  Range(Char, Char)
  ClassShorthand(Char)
}

///| The rule grammar: the language of the bodies a registry stores.
pub enum Node {
  Literal(Char)
  Any
  AnchorStart
  AnchorEnd
  Shorthand(Char)
  Class(Bool, Array[ClassItem])
  Seq(Array[Node])
  Alt(Array[Node])
  Repeat(Node, Int, Int)
}

///| Why a rule body could not be parsed.
pub enum RuleError {
  UnbalancedParen(Int)
  UnbalancedClass(Int)
  NothingToRepeat(Int)
  BadRepeat(Int)
  TrailingEscape(Int)
  EmptyRule(Int)
}

///| A parsed node together with the position just after it.
pub struct Parsed {
  node : Node
  next : Int
}

fn char_text(c : Char) -> String {
  let sb : StringBuilder = StringBuilder()
  sb.write_char(c)
  sb.to_string()
}

fn is_digit_char(c : Char) -> Bool {
  let code = c.to_int()
  code >= 48 && code <= 57
}

fn is_shorthand(c : Char) -> Bool {
  c == 'd' || c == 'D' || c == 'w' || c == 'W' || c == 's' || c == 'S'
}

///| Parse one rule body into a node tree.
pub fn parse_rule(text : String) -> Result[Node, RuleError] {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let len = chars.length()
  if len == 0 {
    return Err(EmptyRule(0))
  }
  match parse_alt(chars, 0, len) {
    Err(error) => Err(error)
    Ok(parsed) => {
      if parsed.next == len {
        Ok(parsed.node)
      } else {
        Err(UnbalancedParen(parsed.next))
      }
    }
  }
}

fn parse_alt(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  match parse_seq(chars, start, len) {
    Err(error) => Err(error)
    Ok(head) => {
      match head {
        None => Err(EmptyRule(start))
        Some(first) => {
          let branches : Array[Node] = [first.node]
          let mut index = first.next
          let mut failure : Option[RuleError] = None
          let mut going = true
          while going {
            if index >= len {
              going = false
            } else if chars[index] != '|' {
              going = false
            } else {
              match parse_seq(chars, index + 1, len) {
                Err(error) => {
                  failure = Some(error)
                  going = false
                }
                Ok(branch) => {
                  match branch {
                    None => {
                      failure = Some(EmptyRule(index + 1))
                      going = false
                    }
                    Some(item) => {
                      branches.push(item.node)
                      index = item.next
                    }
                  }
                }
              }
            }
          }
          match failure {
            Some(error) => Err(error)
            None => {
              if branches.length() == 1 {
                Ok({ node : first.node, next : index })
              } else {
                Ok({ node : Alt(branches), next : index })
              }
            }
          }
        }
      }
    }
  }
}

fn parse_seq(chars : Array[Char], start : Int, len : Int) -> Result[Option[Parsed], RuleError] {
  let items : Array[Node] = []
  let mut index = start
  let mut failure : Option[RuleError] = None
  let mut stop = false
  while !stop {
    if index >= len {
      stop = true
    } else if chars[index] == '|' || chars[index] == ')' {
      stop = true
    } else {
      match parse_repeat(chars, index, len) {
        Err(error) => {
          failure = Some(error)
          stop = true
        }
        Ok(parsed) => {
          items.push(parsed.node)
          index = parsed.next
        }
      }
    }
  }
  match failure {
    Some(error) => Err(error)
    None => {
      let count = items.length()
      if count == 0 {
        Ok(None)
      } else if count == 1 {
        Ok(Some({ node : items[0], next : index }))
      } else {
        Ok(Some({ node : Seq(items), next : index }))
      }
    }
  }
}

fn parse_repeat(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  match parse_atom(chars, start, len) {
    Err(error) => Err(error)
    Ok(atom) => {
      if atom.next >= len {
        Ok(atom)
      } else {
        let marker = chars[atom.next]
        if marker == '*' {
          Ok({ node : Repeat(atom.node, 0, -1), next : atom.next + 1 })
        } else if marker == '+' {
          Ok({ node : Repeat(atom.node, 1, -1), next : atom.next + 1 })
        } else if marker == '?' {
          Ok({ node : Repeat(atom.node, 0, 1), next : atom.next + 1 })
        } else if marker == '{' {
          parse_bounded(atom.node, chars, atom.next, len)
        } else {
          Ok(atom)
        }
      }
    }
  }
}

fn parse_atom(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  let c = chars[start]
  if c == '(' {
    parse_group(chars, start, len)
  } else if c == '[' {
    parse_class(chars, start, len)
  } else if c == '\\' {
    parse_escape(chars, start, len)
  } else if c == '.' {
    Ok({ node : Any, next : start + 1 })
  } else if c == '^' {
    Ok({ node : AnchorStart, next : start + 1 })
  } else if c == '$' {
    Ok({ node : AnchorEnd, next : start + 1 })
  } else if c == '*' || c == '+' || c == '?' || c == '{' {
    Err(NothingToRepeat(start))
  } else {
    Ok({ node : Literal(c), next : start + 1 })
  }
}

fn parse_escape(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  if start + 1 >= len {
    Err(TrailingEscape(start))
  } else {
    let escaped = chars[start + 1]
    if is_shorthand(escaped) {
      Ok({ node : Shorthand(escaped), next : start + 2 })
    } else {
      Ok({ node : Literal(escaped), next : start + 2 })
    }
  }
}

fn parse_group(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  let mut inner = start + 1
  if inner + 1 < len && chars[inner] == '?' && chars[inner + 1] == ':' {
    inner = inner + 2
  }
  match parse_alt(chars, inner, len) {
    Err(error) => Err(error)
    Ok(parsed) => {
      if parsed.next < len && chars[parsed.next] == ')' {
        Ok({ node : parsed.node, next : parsed.next + 1 })
      } else {
        Err(UnbalancedParen(start))
      }
    }
  }
}

fn parse_class(chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  let mut index = start + 1
  let mut negated = false
  if index < len && chars[index] == '^' {
    negated = true
    index = index + 1
  }
  let items : Array[ClassItem] = []
  let mut failure : Option[RuleError] = None
  let mut done = false
  let mut close_at = -1
  while !done {
    if index >= len {
      failure = Some(UnbalancedClass(start))
      done = true
    } else if chars[index] == ']' {
      close_at = index
      done = true
    } else if chars[index] == '\\' {
      if index + 1 >= len {
        failure = Some(TrailingEscape(index))
        done = true
      } else {
        let escaped = chars[index + 1]
        if is_shorthand(escaped) {
          items.push(ClassShorthand(escaped))
        } else {
          items.push(Single(escaped))
        }
        index = index + 2
      }
    } else if index + 2 < len && chars[index + 1] == '-' && chars[index + 2] != ']' {
      items.push(Range(chars[index], chars[index + 2]))
      index = index + 3
    } else {
      items.push(Single(chars[index]))
      index = index + 1
    }
  }
  match failure {
    Some(error) => Err(error)
    None => Ok({ node : Class(negated, items), next : close_at + 1 })
  }
}

fn parse_bounded(node : Node, chars : Array[Char], start : Int, len : Int) -> Result[Parsed, RuleError] {
  let mut index = start + 1
  let mut low = 0
  let mut low_digits = 0
  while index < len && is_digit_char(chars[index]) {
    low = low * 10 + (chars[index].to_int() - 48)
    low_digits = low_digits + 1
    index = index + 1
  }
  if low_digits == 0 {
    return Err(BadRepeat(start))
  }
  let mut high = low
  let mut unbounded = false
  if index < len && chars[index] == ',' {
    index = index + 1
    let mut high_digits = 0
    high = 0
    while index < len && is_digit_char(chars[index]) {
      high = high * 10 + (chars[index].to_int() - 48)
      high_digits = high_digits + 1
      index = index + 1
    }
    if high_digits == 0 {
      unbounded = true
      high = -1
    }
  }
  if index >= len || chars[index] != '}' {
    return Err(BadRepeat(start))
  }
  if !unbounded && high < low {
    return Err(BadRepeat(start))
  }
  Ok({ node : Repeat(node, low, high), next : index + 1 })
}

fn render_high(high : Int) -> String {
  if high < 0 {
    "inf"
  } else {
    high.to_string()
  }
}

fn render_class_item(item : ClassItem) -> String {
  match item {
    Single(c) => char_text(c)
    Range(low, high) => char_text(low) + "-" + char_text(high)
    ClassShorthand(c) => "bs(" + char_text(c) + ")"
  }
}

fn render_class(negated : Bool, items : Array[ClassItem]) -> String {
  let mut body = ""
  let mut first = true
  for item in items {
    let piece = render_class_item(item)
    if first {
      body = body + piece
      first = false
    } else {
      body = body + "," + piece
    }
  }
  if negated {
    "cls(^" + body + ")"
  } else {
    "cls(" + body + ")"
  }
}

fn render_list(prefix : String, items : Array[Node], separator : String) -> String {
  let mut body = ""
  let mut first = true
  for item in items {
    let piece = render_node(item)
    if first {
      body = body + piece
      first = false
    } else {
      body = body + separator + piece
    }
  }
  prefix + body + ")"
}

///| Render a node tree in a stable one-line form.
pub fn render_node(node : Node) -> String {
  match node {
    Literal(c) => "lit(" + char_text(c) + ")"
    Any => "any"
    AnchorStart => "^"
    AnchorEnd => "$"
    Shorthand(c) => "bs(" + char_text(c) + ")"
    Class(negated, items) => render_class(negated, items)
    Seq(items) => render_list("seq(", items, " ")
    Alt(items) => render_list("alt(", items, "|")
    Repeat(inner, low, high) => "rep(" + low.to_string() + "," + render_high(high) + "," + render_node(inner) + ")"
  }
}

///| Render a rule failure as one stable line.
pub fn describe_rule_error(error : RuleError) -> String {
  match error {
    UnbalancedParen(offset) => "unbalanced group at offset " + offset.to_string()
    UnbalancedClass(offset) => "unbalanced character class at offset " + offset.to_string()
    NothingToRepeat(offset) => "nothing to repeat at offset " + offset.to_string()
    BadRepeat(offset) => "malformed repetition at offset " + offset.to_string()
    TrailingEscape(offset) => "trailing escape at offset " + offset.to_string()
    EmptyRule(offset) => "empty rule body at offset " + offset.to_string()
  }
}