///|
/// One recorded capture: which slot, and the half-open character span it covers.
pub struct Span {
  slot : Int32
  start : Int32
  stop : Int32
}

///|
/// A partial match: the position it reached and the spans recorded on the way.
pub struct Branch {
  stop : Int32
  spans : Array[Span]
}

///|
/// The field table of a successful match, in pattern order.
pub struct Fields {
  names : Array[String]
  values : Array[String]
}

///|
/// Number of fields in the table.
pub fn Fields::size(self : Fields) -> Int32 {
  self.names.length()
}

///|
/// The field name at one index, in pattern order.
pub fn Fields::name_at(self : Fields, index : Int32) -> String {
  self.names[index]
}

///|
/// The value captured for the field at one index.
pub fn Fields::value_at(self : Fields, index : Int32) -> String {
  self.values[index]
}

///|
/// The value of a named field, or none when the pattern does not declare it.
pub fn Fields::get(self : Fields, name : String) -> String? {
  let mut index = 0
  let mut found : String? = None
  while index < self.names.length() {
    match found {
      None => if self.names[index] == name { found = Some(self.values[index]) }
      Some(_) => ()
    }
    index = index + 1
  }
  found
}

///|
/// Whether the pattern declares a given field name.
pub fn Fields::has(self : Fields, name : String) -> Bool {
  match self.get(name) {
    Some(_) => true
    None => false
  }
}

///|
/// Why a line could not be matched.
pub struct MatchFailure {
  furthest : Int32
  line_length : Int32
  expected : String
}

///|
/// The furthest position a failed search reached, and what it was trying there.
pub fn MatchFailure::furthest(self : MatchFailure) -> Int32 {
  self.furthest
}

///|
/// Length of the input line, so a caller can say "3 of 12".
pub fn MatchFailure::line_length(self : MatchFailure) -> Int32 {
  self.line_length
}

///|
/// The instruction the search was trying at the furthest position.
pub fn MatchFailure::expected(self : MatchFailure) -> String {
  self.expected
}

///|
/// Why a line could not be matched.
pub enum MatchError {
  NoMatch(MatchFailure)
  StepBudget(Int32, MatchFailure)
}

///|
/// A mutable probe, so the search can report where it got stuck.
priv struct Probe {
  furthest : Array[Int32]
  expected : Array[String]
}

///|
fn note_progress(probe : Probe, pos : Int32, instr : @compile.Instr) -> Unit {
  if pos > probe.furthest[0] {
    probe.furthest[0] = pos
    probe.expected[0] = @compile.render_instr(instr)
  }
}

///|
fn failure_of(input : Array[Char], probe : Probe) -> MatchFailure {
  let reached = if probe.furthest[0] < 0 { 0 } else { probe.furthest[0] }
  {
    furthest: reached,
    line_length: input.length(),
    expected: probe.expected[0],
  }
}

///|
fn char_code(c : Char) -> Int32 {
  c.to_int()
}

///|
fn digit_char(c : Char) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
}

///|
fn letter_char(c : Char) -> Bool {
  let code = char_code(c)
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
fn word_char(c : Char) -> Bool {
  digit_char(c) || letter_char(c) || c == '_'
}

///|
fn space_char(c : Char) -> Bool {
  let code = char_code(c)
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
fn shorthand_char(kind : Char, c : Char) -> Bool {
  if kind == 'd' {
    digit_char(c)
  } else if kind == 'D' {
    !digit_char(c)
  } else if kind == 'w' {
    word_char(c)
  } else if kind == 'W' {
    !word_char(c)
  } else if kind == 's' {
    space_char(c)
  } else {
    !space_char(c)
  }
}

///|
fn class_item_hit(item : @compile.ClassItem, c : Char) -> Bool {
  match item {
    @compile.Single(want) => c == want
    @compile.Range(low, high) => {
      let code = char_code(c)
      code >= char_code(low) && code <= char_code(high)
    }
    @compile.ClassShorthand(kind) => shorthand_char(kind, c)
  }
}

///|
fn class_hit(
  negated : Bool,
  items : Array[@compile.ClassItem],
  c : Char,
) -> Bool {
  let mut index = 0
  let mut hit = false
  while index < items.length() {
    if class_item_hit(items[index], c) {
      hit = true
    }
    index = index + 1
  }
  if negated {
    !hit
  } else {
    hit
  }
}

///|
fn copy_spans(spans : Array[Span]) -> Array[Span] {
  let out : Array[Span] = []
  for span in spans {
    out.push(span)
  }
  out
}

///|
fn join_spans(left : Array[Span], right : Array[Span]) -> Array[Span] {
  let out = copy_spans(left)
  for span in right {
    out.push(span)
  }
  out
}

///|
fn push_span(spans : Array[Span], span : Span) -> Array[Span] {
  let out = copy_spans(spans)
  out.push(span)
  out
}

///|
fn single_branch(stop : Int32) -> Array[Branch] {
  let out : Array[Branch] = []
  out.push({ stop, spans: [], })
  out
}

///|
fn spend(budget : Array[Int32]) -> Unit {
  budget[0] = budget[0] + 1
}

///|
fn cap_branches(
  branches : Array[Branch],
  overflow : Array[Int32],
) -> Array[Branch] {
  if branches.length() > 64 {
    overflow[0] = overflow[0] + 1
    let kept : Array[Branch] = []
    let mut index = 0
    while index < 64 {
      kept.push(branches[index])
      index = index + 1
    }
    kept
  } else {
    branches
  }
}

///|
fn slice_text(input : Array[Char], start : Int32, stop : Int32) -> String {
  let sb : StringBuilder = StringBuilder()
  let mut index = start
  while index < stop && index < input.length() {
    sb.write_char(input[index])
    index = index + 1
  }
  sb.to_string()
}

///|
fn ends_of(
  instr : @compile.Instr,
  input : Array[Char],
  pos : Int32,
  budget : Array[Int32],
  overflow : Array[Int32],
  probe : Probe,
) -> Array[Branch] {
  spend(budget)
  note_progress(probe, pos, instr)
  let nothing : Array[Branch] = []
  if budget[0] > budget[1] {
    overflow[0] = overflow[0] + 1
    return nothing
  }
  let len = input.length()
  match instr {
    @compile.Char(want) =>
      if pos < len && input[pos] == want {
        single_branch(pos + 1)
      } else {
        nothing
      }
    @compile.AnyChar => if pos < len { single_branch(pos + 1) } else { nothing }
    @compile.AnchorStart => if pos == 0 { single_branch(pos) } else { nothing }
    @compile.AnchorEnd => if pos == len { single_branch(pos) } else { nothing }
    @compile.Shorthand(kind) =>
      if pos < len && shorthand_char(kind, input[pos]) {
        single_branch(pos + 1)
      } else {
        nothing
      }
    @compile.Class(negated, items) =>
      if pos < len && class_hit(negated, items, input[pos]) {
        single_branch(pos + 1)
      } else {
        nothing
      }
    @compile.Seq(items) => seq_ends(items, input, pos, budget, overflow, probe)
    @compile.Alt(items) => alt_ends(items, input, pos, budget, overflow, probe)
    @compile.Repeat(inner, low, high) =>
      repeat_ends(inner, low, high, input, pos, budget, overflow, probe)
    @compile.Capture(slot, inner) =>
      capture_ends(slot, inner, input, pos, budget, overflow, probe)
  }
}

///|
fn seq_ends(
  items : Array[@compile.Instr],
  input : Array[Char],
  pos : Int32,
  budget : Array[Int32],
  overflow : Array[Int32],
  probe : Probe,
) -> Array[Branch] {
  let mut current : Array[Branch] = []
  current.push({ stop: pos, spans: [], })
  for item in items {
    let next : Array[Branch] = []
    for branch in current {
      let pieces = ends_of(item, input, branch.stop, budget, overflow, probe)
      for piece in pieces {
        next.push({
          stop: piece.stop,
          spans: join_spans(branch.spans, piece.spans),
        })
      }
    }
    current = cap_branches(next, overflow)
  }
  current
}

///|
fn alt_ends(
  items : Array[@compile.Instr],
  input : Array[Char],
  pos : Int32,
  budget : Array[Int32],
  overflow : Array[Int32],
  probe : Probe,
) -> Array[Branch] {
  let out : Array[Branch] = []
  for item in items {
    let pieces = ends_of(item, input, pos, budget, overflow, probe)
    for piece in pieces {
      out.push(piece)
    }
  }
  cap_branches(out, overflow)
}

///|
fn repeat_ends(
  inner : @compile.Instr,
  low : Int32,
  high : Int32,
  input : Array[Char],
  pos : Int32,
  budget : Array[Int32],
  overflow : Array[Int32],
  probe : Probe,
) -> Array[Branch] {
  let len = input.length()
  let cap = if high < 0 { len + 1 } else { high }
  let results : Array[Branch] = []
  if low == 0 {
    results.push({ stop: pos, spans: [], })
  }
  let mut frontier : Array[Branch] = []
  frontier.push({ stop: pos, spans: [], })
  let mut count = 0
  let mut going = true
  while going && count < cap {
    let next : Array[Branch] = []
    for branch in frontier {
      let pieces = ends_of(inner, input, branch.stop, budget, overflow, probe)
      for piece in pieces {
        if piece.stop > branch.stop {
          next.push({
            stop: piece.stop,
            spans: join_spans(branch.spans, piece.spans),
          })
        }
      }
    }
    count = count + 1
    if next.length() == 0 {
      going = false
    } else {
      frontier = cap_branches(next, overflow)
      if count >= low {
        for branch in frontier {
          results.push(branch)
        }
      }
    }
  }
  let ordered : Array[Branch] = []
  let mut index = results.length() - 1
  while index >= 0 {
    ordered.push(results[index])
    index = index - 1
  }
  ordered
}

///|
fn capture_ends(
  slot : Int32,
  inner : @compile.Instr,
  input : Array[Char],
  pos : Int32,
  budget : Array[Int32],
  overflow : Array[Int32],
  probe : Probe,
) -> Array[Branch] {
  let pieces = ends_of(inner, input, pos, budget, overflow, probe)
  let out : Array[Branch] = []
  for piece in pieces {
    out.push({
      stop: piece.stop,
      spans: push_span(piece.spans, { slot, start: pos, stop: piece.stop, }),
    })
  }
  out
}

///|
/// Match one line against a compiled program with an explicit step budget.
///
/// A line must match in full. A partial match is a failure, not a best-effort
/// result, so a caller never receives half a field table.
pub fn match_line_with_limit(
  program : @compile.Program,
  line : String,
  step_limit : Int32,
) -> Result[Fields, MatchError] {
  let input : Array[Char] = []
  for c in line {
    input.push(c)
  }
  let probe : Probe = { furthest: [-1], expected: [""], }
  let budget : Array[Int32] = [0, step_limit]
  let overflow : Array[Int32] = [0]
  let branches = ends_of(program.root(), input, 0, budget, overflow, probe)
  let len = input.length()
  let mut chosen : Branch? = None
  let mut index = 0
  while index < branches.length() {
    let branch = branches[index]
    if branch.stop == len {
      match chosen {
        None => chosen = Some(branch)
        Some(_) => ()
      }
    }
    index = index + 1
  }
  match chosen {
    None =>
      if overflow[0] > 0 {
        Err(StepBudget(step_limit, failure_of(input, probe)))
      } else {
        Err(NoMatch(failure_of(input, probe)))
      }
    Some(branch) => {
      let names = program.field_names()
      let values : Array[String] = []
      let mut slot = 0
      while slot < names.length() {
        let mut text = ""
        let mut span_index = 0
        while span_index < branch.spans.length() {
          let span = branch.spans[span_index]
          if span.slot == slot {
            text = slice_text(input, span.start, span.stop)
          }
          span_index = span_index + 1
        }
        values.push(text)
        slot = slot + 1
      }
      Ok({ names, values, })
    }
  }
}

///|
/// Match one line against a compiled program with the default step budget.
pub fn match_line(
  program : @compile.Program,
  line : String,
) -> Result[Fields, MatchError] {
  match_line_with_limit(program, line, 200000)
}

///|
/// Render a match failure as one stable line.
pub fn describe_match_error(error : MatchError) -> String {
  match error {
    NoMatch(_) => "line does not match the pattern"
    StepBudget(limit, _) =>
      "pattern exceeded the step budget of " + limit.to_string() + " steps"
  }
}

///|
/// Render why a line failed, with the position the search reached.
///
/// The summary stays stable for callers that only branch on success; this detail is
/// what a person needs while writing a pattern.
pub fn describe_failure(error : MatchError) -> String {
  match error {
    NoMatch(failure) =>
      "no match: reached position " +
      failure.furthest.to_string() +
      " of " +
      failure.line_length.to_string() +
      " while trying " +
      failure.expected
    StepBudget(limit, failure) =>
      "step budget of " +
      limit.to_string() +
      " exhausted at position " +
      failure.furthest.to_string() +
      " of " +
      failure.line_length.to_string() +
      " while trying " +
      failure.expected
  }
}
