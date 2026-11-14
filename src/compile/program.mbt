///|
/// One matcher instruction.
///
/// Capture slots are numbered in pattern order at compile time, so the engine
/// never has to know a field name.
pub enum Instr {
  Char(Char)
  AnyChar
  AnchorStart
  AnchorEnd
  Shorthand(Char)
  Class(Bool, Array[ClassItem])
  Seq(Array[Instr])
  Alt(Array[Instr])
  Repeat(Instr, Int32, Int32)
  Capture(Int32, Instr)
}

///|
/// A compiled pattern: one instruction tree plus the field table.
pub struct Program {
  instr : Instr
  fields : Array[String]
}

///|
/// Number of capture slots, which is also the number of named fields.
pub fn Program::field_count(self : Program) -> Int32 {
  self.fields.length()
}

///|
/// The field name attached to one slot.
pub fn Program::field_at(self : Program, index : Int32) -> String {
  self.fields[index]
}

///|
/// Why a pattern could not be compiled.
pub enum CompileError {
  PatternBad(@syntax.ParseError)
  RegistryBad(@registry.RegistryError)
  RuleBad(RuleError)
  DuplicateField(String)
  EmptyPattern
}

///|
fn lower(node : Node) -> Instr {
  match node {
    Literal(c) => Char(c)
    Any => AnyChar
    AnchorStart => AnchorStart
    AnchorEnd => AnchorEnd
    Shorthand(c) => Shorthand(c)
    Class(negated, items) => Class(negated, items)
    Seq(items) => {
      let lowered : Array[Instr] = []
      for item in items {
        lowered.push(lower(item))
      }
      Seq(lowered)
    }
    Alt(items) => {
      let lowered : Array[Instr] = []
      for item in items {
        lowered.push(lower(item))
      }
      Alt(lowered)
    }
    Repeat(inner, low, high) => Repeat(lower(inner), low, high)
  }
}

///|
fn emit_literal(text : String, out : Array[Instr]) -> Unit {
  for c in text {
    out.push(Char(c))
  }
}

///|
fn contains_field(fields : Array[String], field : String) -> Bool {
  let mut index = 0
  let mut hit = false
  while index < fields.length() {
    if fields[index] == field {
      hit = true
    }
    index = index + 1
  }
  hit
}

///|
fn place_capture(
  reference : @syntax.PatternRef,
  node : Node,
  out : Array[Instr],
  fields : Array[String],
) -> Result[Unit, CompileError] {
  match reference.ref_field() {
    None => {
      out.push(lower(node))
      Ok(())
    }
    Some(field) =>
      if contains_field(fields, field) {
        Err(DuplicateField(field))
      } else {
        let slot = fields.length()
        fields.push(field)
        out.push(Capture(slot, lower(node)))
        Ok(())
      }
  }
}

///|
fn emit_reference(
  registry : @registry.Registry,
  reference : @syntax.PatternRef,
  out : Array[Instr],
  fields : Array[String],
) -> Result[Unit, CompileError] {
  match @registry.resolve(registry, reference.ref_name()) {
    Err(error) => Err(RegistryBad(error))
    Ok(body) =>
      match parse_rule(body) {
        Err(error) => Err(RuleBad(error))
        Ok(node) => place_capture(reference, node, out, fields)
      }
  }
}

///|
fn emit_segment(
  registry : @registry.Registry,
  segment : @syntax.Segment,
  out : Array[Instr],
  fields : Array[String],
) -> Result[Unit, CompileError] {
  match segment {
    @syntax.Literal(text) => {
      emit_literal(text, out)
      Ok(())
    }
    @syntax.Ref(reference) => emit_reference(registry, reference, out, fields)
  }
}

///|
/// Compile pattern text against a registry into a program and its field table.
///
/// Every static failure is caught here: malformed pattern text, an unknown rule,
/// a malformed rule body, a field declared twice, and an empty pattern. The hot
/// path therefore carries no check that can surprise a caller.
pub fn compile(
  registry : @registry.Registry,
  pattern_text : String,
) -> Result[Program, CompileError] {
  match @syntax.parse(pattern_text) {
    Err(error) => Err(PatternBad(error))
    Ok(pattern) => {
      let total = pattern.segment_count()
      if total == 0 {
        Err(EmptyPattern)
      } else {
        let instrs : Array[Instr] = []
        let fields : Array[String] = []
        let mut index = 0
        let mut failed = false
        let mut failure : CompileError? = None
        while index < total && !failed {
          match
            emit_segment(registry, pattern.segment_at(index), instrs, fields) {
            Err(error) => {
              failure = Some(error)
              failed = true
            }
            Ok(_) => ()
          }
          index = index + 1
        }
        match failure {
          Some(error) => Err(error)
          None => {
            let instr = if instrs.length() == 1 {
              instrs[0]
            } else {
              Seq(instrs)
            }
            Ok({ instr, fields, })
          }
        }
      }
    }
  }
}

///|
fn render_instr_list(
  prefix : String,
  items : Array[Instr],
  separator : String,
) -> String {
  let mut body = ""
  let mut first = true
  for item in items {
    let piece = render_instr(item)
    if first {
      body = body + piece
      first = false
    } else {
      body = body + separator + piece
    }
  }
  prefix + body + ")"
}

///|
/// Render one instruction in a stable one-line form.
pub fn render_instr(instr : Instr) -> String {
  match instr {
    Char(c) => "ch(" + char_text(c) + ")"
    AnyChar => "any"
    AnchorStart => "^"
    AnchorEnd => "$"
    Shorthand(c) => "bs(" + char_text(c) + ")"
    Class(negated, items) => render_class(negated, items)
    Seq(items) => render_instr_list("seq(", items, " ")
    Alt(items) => render_instr_list("alt(", items, "|")
    Repeat(inner, low, high) =>
      "rep(" +
      low.to_string() +
      "," +
      render_high(high) +
      "," +
      render_instr(inner) +
      ")"
    Capture(slot, inner) =>
      "cap(" + slot.to_string() + "," + render_instr(inner) + ")"
  }
}

///|
fn join_fields(fields : Array[String]) -> String {
  let mut text = ""
  let mut first = true
  for field in fields {
    if first {
      text = text + field
      first = false
    } else {
      text = text + "," + field
    }
  }
  text
}

///|
/// Render a whole program, field table included, in a stable one-line form.
pub fn render_program(program : Program) -> String {
  render_instr(program.instr) + " fields=[" + join_fields(program.fields) + "]"
}

///|
/// Render a compile failure as one stable line.
pub fn describe_compile_error(error : CompileError) -> String {
  match error {
    PatternBad(inner) => "pattern: " + @syntax.describe_error(inner)
    RegistryBad(inner) =>
      "registry: " + @registry.describe_registry_error(inner)
    RuleBad(inner) => "rule: " + describe_rule_error(inner)
    DuplicateField(field) => "duplicate field: " + field
    EmptyPattern => "empty pattern"
  }
}

///|
/// The instruction tree this program executes.
pub fn Program::root(self : Program) -> Instr {
  self.instr
}

///|
/// The field names, indexed by capture slot.
pub fn Program::field_names(self : Program) -> Array[String] {
  self.fields
}
