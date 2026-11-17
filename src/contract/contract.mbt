///|
/// One semantic check applied to a field value.
pub enum Check {
  IsInteger
  Between(Int32, Int32)
  OneOf(Array[String])
  MinLength(Int32)
  MaxLength(Int32)
}

///|
/// One declared field and the checks that apply to it.
pub struct FieldContract {
  field : String
  required : Bool
  checks : Array[Check]
}

///|
/// A cross-field comparison, evaluated only when both sides parse as integers.
pub struct CrossCheck {
  left : String
  right : String
}

///|
/// A set of field contracts.
pub struct Contract {
  fields : Array[FieldContract]
  crosses : Array[CrossCheck]
}

///|
/// One violation found by validation.
pub enum Violation {
  Missing(String)
  NotAnInteger(String, String)
  OutOfInt32(String, String)
  OutOfRange(String, String, Int32, Int32)
  NotOneOf(String, String)
  TooShort(String, String, Int32)
  TooLong(String, String, Int32)
  CrossFails(String, String, String, String)
}

///|
/// The outcome of reading a field as a number.
pub enum ParsedInt {
  Fits(Int32)
  TooLarge
  NotANumber
}

///|
/// An empty contract.
pub fn contract() -> Contract {
  { fields: [], crosses: [], }
}

///|
fn find_field(contract : Contract, field : String) -> Int32 {
  let mut index = 0
  let mut found = -1
  while index < contract.fields.length() {
    if found == -1 && contract.fields[index].field == field {
      found = index
    }
    index = index + 1
  }
  found
}

///|
fn ensure_entry(contract : Contract, field : String) -> Int32 {
  let at = find_field(contract, field)
  if at >= 0 {
    at
  } else {
    let fresh : FieldContract = { field, required: false, checks: [], }
    contract.fields.push(fresh)
    contract.fields.length() - 1
  }
}

///|
/// Require the field to be present.
pub fn Contract::require(self : Contract, field : String) -> Unit {
  let at = ensure_entry(self, field)
  let entry = self.fields[at]
  self.fields[at] = {
    field: entry.field,
    required: true,
    checks: entry.checks,
  }
}

///|
fn add_check(contract : Contract, field : String, check : Check) -> Unit {
  let at = ensure_entry(contract, field)
  let entry = contract.fields[at]
  let next : Array[Check] = []
  for existing in entry.checks {
    next.push(existing)
  }
  next.push(check)
  contract.fields[at] = {
    field: entry.field,
    required: entry.required,
    checks: next,
  }
}

///|
/// Require the field value to be an integer.
pub fn Contract::is_integer(self : Contract, field : String) -> Unit {
  add_check(self, field, IsInteger)
}

///|
/// Require the integer value to fall inside a closed range.
pub fn Contract::between(
  self : Contract,
  field : String,
  low : Int32,
  high : Int32,
) -> Unit {
  add_check(self, field, Between(low, high))
}

///|
/// Require the value to be one of a fixed set.
pub fn Contract::one_of(
  self : Contract,
  field : String,
  values : Array[String],
) -> Unit {
  add_check(self, field, OneOf(values))
}

///|
/// Require at least a number of characters.
pub fn Contract::min_length(
  self : Contract,
  field : String,
  least : Int32,
) -> Unit {
  add_check(self, field, MinLength(least))
}

///|
/// Allow at most a number of characters.
pub fn Contract::max_length(
  self : Contract,
  field : String,
  most : Int32,
) -> Unit {
  add_check(self, field, MaxLength(most))
}

///|
/// Require the left field, read as an integer, to be at least the right one.
pub fn Contract::greater_or_equal(
  self : Contract,
  left : String,
  right : String,
) -> Unit {
  self.crosses.push({ left, right, })
}

///|
/// Read the field text as a signed 32-bit integer.
///
/// A magnitude that does not fit is reported as `TooLarge` rather than wrapped:
/// silent wrapping would let an out-of-range value satisfy a range check.
fn parse_integer(text : String) -> ParsedInt {
  let chars : Array[Char] = []
  for c in text {
    chars.push(c)
  }
  let total = chars.length()
  if total == 0 {
    return NotANumber
  }
  let mut index = 0
  let mut negative = false
  if chars[0] == '-' {
    negative = true
    index = 1
  } else if chars[0] == '+' {
    index = 1
  }
  if index >= total {
    return NotANumber
  }
  let mut value : Int32 = 0
  let mut overflow = false
  while index < total {
    let code = chars[index].to_int()
    if code < 48 || code > 57 {
      return NotANumber
    }
    let digit = code - 48
    if value > 214748364 {
      overflow = true
    } else if value == 214748364 && digit > 7 {
      overflow = true
    }
    if !overflow {
      value = value * 10 + digit
    }
    index = index + 1
  }
  if overflow {
    TooLarge
  } else if negative {
    Fits(-value)
  } else {
    Fits(value)
  }
}

///|
fn contains_value(values : Array[String], value : String) -> Bool {
  let mut index = 0
  let mut hit = false
  while index < values.length() {
    if values[index] == value {
      hit = true
    }
    index = index + 1
  }
  hit
}

///|
fn check_value(
  field : String,
  value : String,
  check : Check,
  out : Array[Violation],
) -> Unit {
  match check {
    IsInteger =>
      match parse_integer(value) {
        Fits(_) => ()
        TooLarge => out.push(OutOfInt32(field, value))
        NotANumber => out.push(NotAnInteger(field, value))
      }
    Between(low, high) =>
      match parse_integer(value) {
        Fits(number) =>
          if number < low || number > high {
            out.push(OutOfRange(field, value, low, high))
          }
        TooLarge => out.push(OutOfInt32(field, value))
        NotANumber => out.push(NotAnInteger(field, value))
      }
    OneOf(values) =>
      if !contains_value(values, value) {
        out.push(NotOneOf(field, value))
      }
    MinLength(least) =>
      if value.length() < least {
        out.push(TooShort(field, value, least))
      }
    MaxLength(most) =>
      if value.length() > most {
        out.push(TooLong(field, value, most))
      }
  }
}

///|
/// Validate a matched field table against a contract.
///
/// Declared fields are checked in declaration order, then every cross-field
/// comparison. A missing optional field is skipped; a missing required field yields
/// one violation and suppresses that field's own per-value checks.
pub fn validate(
  fields : @engine.Fields,
  contract : Contract,
) -> Array[Violation] {
  let out : Array[Violation] = []
  let mut index = 0
  while index < contract.fields.length() {
    let entry = contract.fields[index]
    match fields.get(entry.field) {
      None => if entry.required { out.push(Missing(entry.field)) }
      Some(value) => {
        let mut check_index = 0
        while check_index < entry.checks.length() {
          check_value(entry.field, value, entry.checks[check_index], out)
          check_index = check_index + 1
        }
      }
    }
    index = index + 1
  }
  let mut cross_index = 0
  while cross_index < contract.crosses.length() {
    let cross = contract.crosses[cross_index]
    match fields.get(cross.left) {
      None => ()
      Some(left_text) =>
        match fields.get(cross.right) {
          None => ()
          Some(right_text) =>
            match parse_integer(left_text) {
              NotANumber => out.push(NotAnInteger(cross.left, left_text))
              TooLarge => out.push(OutOfInt32(cross.left, left_text))
              Fits(left_number) =>
                match parse_integer(right_text) {
                  NotANumber => out.push(NotAnInteger(cross.right, right_text))
                  TooLarge => out.push(OutOfInt32(cross.right, right_text))
                  Fits(right_number) =>
                    if left_number < right_number {
                      out.push(
                        CrossFails(
                          cross.left,
                          left_text,
                          cross.right,
                          right_text,
                        ),
                      )
                    }
                }
            }
        }
    }
    cross_index = cross_index + 1
  }
  out
}

///|
/// Render a violation as one stable line.
pub fn describe_violation(violation : Violation) -> String {
  match violation {
    Missing(field) => "missing required field: " + field
    NotAnInteger(field, value) =>
      "field " + field + " is not an integer: " + value
    OutOfInt32(field, value) =>
      "field " + field + " does not fit a 32-bit integer: " + value
    OutOfRange(field, value, low, high) =>
      "field " +
      field +
      " is out of range " +
      low.to_string() +
      ".." +
      high.to_string() +
      ": " +
      value
    NotOneOf(field, value) =>
      "field " + field + " is not one of the allowed values: " + value
    TooShort(field, value, least) =>
      "field " + field + " is shorter than " + least.to_string() + ": " + value
    TooLong(field, value, most) =>
      "field " + field + " is longer than " + most.to_string() + ": " + value
    CrossFails(left, left_text, right, right_text) =>
      "field " +
      left +
      " (" +
      left_text +
      ") must be at least field " +
      right +
      " (" +
      right_text +
      ")"
  }
}
