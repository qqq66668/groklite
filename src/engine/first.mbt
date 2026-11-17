///|
/// The outcome of trying several programs in order.
pub struct FirstMatch {
  index : Int32
  fields : Fields
}

///|
/// Which program matched, counted from zero in the order it was tried.
pub fn FirstMatch::first_pattern_index(self : FirstMatch) -> Int32 {
  self.index
}

///|
/// The field table produced by the matching program.
pub fn FirstMatch::first_matched_fields(self : FirstMatch) -> Fields {
  self.fields
}

///|
/// Try programs in order and return the first one that matches the whole line.
///
/// A step budget failure stops the search rather than being read as a miss: a
/// caller who asked for a match wants to know that a pattern was abandoned, not
/// that the line looked like none of them.
pub fn match_first_with_limit(
  programs : Array[@compile.Program],
  line : String,
  step_limit : Int32,
) -> Result[FirstMatch, MatchError] {
  let mut index = 0
  let mut outcome : Result[FirstMatch, MatchError] = Err(
    NoMatch({ furthest: 0, line_length: 0, expected: "", }),
  )
  let mut decided = false
  while index < programs.length() && !decided {
    match match_line_with_limit(programs[index], line, step_limit) {
      Ok(fields) => {
        outcome = Ok({ index, fields, })
        decided = true
      }
      Err(error) =>
        match error {
          StepBudget(limit, failure) => {
            outcome = Err(StepBudget(limit, failure))
            decided = true
          }
          NoMatch(_) => ()
        }
    }
    index = index + 1
  }
  outcome
}

///|
/// Try programs in order and return the first one that matches the whole line.
pub fn match_first(
  programs : Array[@compile.Program],
  line : String,
) -> Result[FirstMatch, MatchError] {
  match_first_with_limit(programs, line, 200000)
}
