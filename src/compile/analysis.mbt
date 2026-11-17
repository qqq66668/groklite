///|
/// A static finding about a compiled program.
pub enum Issue {
  EmptyLoop
  AnchorFollowedByConsumer(Int32)
  AnchorStartAfterConsumer(Int32)
  DuplicateBranch(Int32)
}

///|
/// Static bounds and findings for one compiled program.
///
/// Bounds are expressed in characters. `None` means the program is not bounded on
/// that axis, which happens as soon as an unbounded repetition over a body that
/// consumes at least one character appears.
pub struct Analysis {
  min_length : Int32
  max_length : Int32?
  max_steps : Int32?
  field_max : Array[Int32?]
  issues : Array[Issue]
}

///|
/// Minimum number of characters the program must consume.
pub fn Analysis::min_chars(self : Analysis) -> Int32 {
  self.min_length
}

///|
/// Maximum number of characters the program may consume, or none when unbounded.
pub fn Analysis::max_chars(self : Analysis) -> Int32? {
  self.max_length
}

///|
/// Upper bound on matcher steps, or none when unbounded.
pub fn Analysis::step_bound(self : Analysis) -> Int32? {
  self.max_steps
}

///|
/// Maximum capture length of one field slot, or none when unbounded.
pub fn Analysis::field_bound(self : Analysis, slot : Int32) -> Int32? {
  self.field_max[slot]
}

///|
/// Number of findings.
pub fn Analysis::issue_count(self : Analysis) -> Int32 {
  self.issues.length()
}

///|
/// The finding at one index.
pub fn Analysis::issue_at(self : Analysis, index : Int32) -> Issue {
  self.issues[index]
}

///|
fn add_max(left : Int32?, right : Int32?) -> Int32? {
  match left {
    None => None
    Some(l) =>
      match right {
        None => None
        Some(r) => Some(l + r)
      }
  }
}

///|
fn pick_max(left : Int32?, right : Int32?) -> Int32? {
  match left {
    None => None
    Some(l) =>
      match right {
        None => None
        Some(r) => Some(if l > r { l } else { r })
      }
  }
}

///|
fn width_of(instr : Instr) -> (Int32, Int32?) {
  match instr {
    Char(_) => (1, Some(1))
    AnyChar => (1, Some(1))
    Shorthand(_) => (1, Some(1))
    Class(_, _) => (1, Some(1))
    AnchorStart => (0, Some(0))
    AnchorEnd => (0, Some(0))
    Capture(_, inner) => width_of(inner)
    Seq(items) => {
      let mut low = 0
      let mut high : Int32? = Some(0)
      for item in items {
        let (item_low, item_high) = width_of(item)
        low = low + item_low
        high = add_max(high, item_high)
      }
      (low, high)
    }
    Alt(items) =>
      if items.length() == 0 {
        (0, Some(0))
      } else {
        let mut low = 0
        let mut high : Int32? = Some(0)
        let mut first = true
        for item in items {
          let (item_low, item_high) = width_of(item)
          if first {
            low = item_low
            high = item_high
            first = false
          } else {
            if item_low < low {
              low = item_low
            }
            high = pick_max(high, item_high)
          }
        }
        (low, high)
      }
    Repeat(inner, low, high) => {
      let (inner_low, inner_high) = width_of(inner)
      let least = low * inner_low
      match inner_high {
        None => (least, None)
        Some(w) =>
          if w == 0 {
            (least, Some(0))
          } else if high < 0 {
            (least, None)
          } else {
            (least, Some(high * w))
          }
      }
    }
  }
}

///|
/// Whether an instruction can match without consuming a character.
fn nullable(instr : Instr) -> Bool {
  match instr {
    Char(_) => false
    AnyChar => false
    Shorthand(_) => false
    Class(_, _) => false
    AnchorStart => true
    AnchorEnd => true
    Capture(_, inner) => nullable(inner)
    Seq(items) => {
      let mut all = true
      for item in items {
        if !nullable(item) {
          all = false
        }
      }
      all
    }
    Alt(items) => {
      let mut any = false
      for item in items {
        if nullable(item) {
          any = true
        }
      }
      any
    }
    Repeat(inner, low, _) => low == 0 || nullable(inner)
  }
}

///|
fn steps_of(instr : Instr) -> Int32? {
  match instr {
    Char(_) => Some(1)
    AnyChar => Some(1)
    Shorthand(_) => Some(1)
    Class(_, _) => Some(1)
    AnchorStart => Some(1)
    AnchorEnd => Some(1)
    Capture(_, inner) => steps_of(inner)
    Seq(items) => {
      let mut total : Int32? = Some(0)
      for item in items {
        total = add_max(total, steps_of(item))
      }
      total
    }
    Alt(items) => {
      let mut total : Int32? = Some(0)
      for item in items {
        total = add_max(total, steps_of(item))
      }
      total
    }
    Repeat(inner, _, high) =>
      match steps_of(inner) {
        None => None
        Some(s) => if high < 0 { None } else { Some(high * s) }
      }
  }
}

///|
fn collect_issues(instr : Instr, issues : Array[Issue]) -> Unit {
  match instr {
    Char(_) => ()
    AnyChar => ()
    Shorthand(_) => ()
    Class(_, _) => ()
    AnchorStart => ()
    AnchorEnd => ()
    Capture(_, inner) => collect_issues(inner, issues)
    Seq(items) => {
      let mut consumed_before = false
      let mut index = 0
      while index < items.length() {
        let item = items[index]
        let (item_low, _) = width_of(item)
        match item {
          AnchorStart =>
            if consumed_before {
              issues.push(AnchorStartAfterConsumer(index))
            }
          AnchorEnd => {
            let mut later = index + 1
            let mut bad = false
            while later < items.length() {
              let (later_low, _) = width_of(items[later])
              if later_low > 0 {
                bad = true
              }
              later = later + 1
            }
            if bad {
              issues.push(AnchorFollowedByConsumer(index))
            }
          }
          _ => ()
        }
        if item_low > 0 {
          consumed_before = true
        }
        collect_issues(item, issues)
        index = index + 1
      }
    }
    Alt(items) => {
      let mut index = 0
      while index < items.length() {
        let rendered = render_instr(items[index])
        let mut earlier = 0
        let mut duplicate = false
        while earlier < index {
          if render_instr(items[earlier]) == rendered {
            duplicate = true
          }
          earlier = earlier + 1
        }
        if duplicate {
          issues.push(DuplicateBranch(index))
        }
        collect_issues(items[index], issues)
        index = index + 1
      }
    }
    Repeat(inner, _, high) => {
      if high < 0 && nullable(inner) {
        issues.push(EmptyLoop)
      }
      collect_issues(inner, issues)
    }
  }
}

///|
fn collect_fields(instr : Instr, bounds : Array[Int32?]) -> Unit {
  match instr {
    Char(_) => ()
    AnyChar => ()
    Shorthand(_) => ()
    Class(_, _) => ()
    AnchorStart => ()
    AnchorEnd => ()
    Capture(slot, inner) => {
      let (_, inner_high) = width_of(inner)
      bounds[slot] = pick_max(bounds[slot], inner_high)
      collect_fields(inner, bounds)
    }
    Seq(items) =>
      for item in items {
        collect_fields(item, bounds)
      }
    Alt(items) =>
      for item in items {
        collect_fields(item, bounds)
      }
    Repeat(inner, _, _) => collect_fields(inner, bounds)
  }
}

///|
/// Analyse a compiled program without running it.
///
/// The report answers questions a caller cannot ask a regular-expression engine:
/// how long a match can be, how many steps the search can take, how long each field
/// can be, and whether the pattern contains a construct that cannot do what it looks
/// like it does.
pub fn analyze(program : Program) -> Analysis {
  let (low, high) = width_of(program.instr)
  let bounds : Array[Int32?] = []
  let mut slot = 0
  while slot < program.fields.length() {
    bounds.push(Some(0))
    slot = slot + 1
  }
  collect_fields(program.instr, bounds)
  let issues : Array[Issue] = []
  collect_issues(program.instr, issues)
  {
    min_length: low,
    max_length: high,
    max_steps: steps_of(program.instr),
    field_max: bounds,
    issues,
  }
}

///|
/// Render a finding as one stable line.
pub fn describe_issue(issue : Issue) -> String {
  match issue {
    EmptyLoop => "unbounded repetition over a body that can match nothing"
    AnchorFollowedByConsumer(at) =>
      "end anchor at index " +
      at.to_string() +
      " is followed by a consuming instruction"
    AnchorStartAfterConsumer(at) =>
      "start anchor at index " +
      at.to_string() +
      " follows a consuming instruction"
    DuplicateBranch(at) =>
      "alternation branch " + at.to_string() + " repeats an earlier branch"
  }
}
