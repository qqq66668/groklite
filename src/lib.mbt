///|
/// Public facade of the module. Every caller-visible name is re-exported here.

///|
/// Parse pattern text into ordered segments.
pub fn parse(text : String) -> Result[@syntax.Pattern, @syntax.ParseError] {
  @syntax.parse(text)
}

///|
/// Render a parsed pattern in its stable one-line form.
pub fn render_pattern(pattern : @syntax.Pattern) -> String {
  @syntax.render_pattern(pattern)
}

///|
/// Render a parse failure as a headline and a caret line.
pub fn describe_error(error : @syntax.ParseError) -> String {
  @syntax.describe_error(error)
}

///|
/// Number of top-level segments in a parsed pattern.
pub fn segment_count(pattern : @syntax.Pattern) -> Int32 {
  pattern.segment_count()
}

///|
/// The curated built-in registry.
pub fn builtin_registry() -> @registry.Registry {
  @registry.builtin()
}

///|
/// Expand one named pattern into a body with no remaining references.
pub fn resolve_pattern(
  registry : @registry.Registry,
  name : String,
) -> Result[String, @registry.RegistryError] {
  @registry.resolve(registry, name)
}

///|
/// Render a registry failure as one stable line.
pub fn describe_registry_error(error : @registry.RegistryError) -> String {
  @registry.describe_registry_error(error)
}

///|
/// Compile pattern text into a program and its field table.
pub fn compile(
  registry : @registry.Registry,
  pattern_text : String,
) -> Result[@compile.Program, @compile.CompileError] {
  @compile.compile(registry, pattern_text)
}

///|
/// Render a compile failure as one stable line.
pub fn describe_compile_error(error : @compile.CompileError) -> String {
  @compile.describe_compile_error(error)
}

///|
/// Render a compiled program, field table included.
pub fn render_program(program : @compile.Program) -> String {
  @compile.render_program(program)
}

///|
/// Compile pattern text against the curated built-in registry.
pub fn compile_builtin(
  pattern_text : String,
) -> Result[@compile.Program, @compile.CompileError] {
  @engine.compile_builtin(pattern_text)
}

///|
/// Match one line against a compiled program.
pub fn match_line(
  program : @compile.Program,
  line : String,
) -> Result[@engine.Fields, @engine.MatchError] {
  @engine.match_line(program, line)
}

///|
/// Match one line against a compiled program with an explicit step budget.
pub fn match_line_with_limit(
  program : @compile.Program,
  line : String,
  step_limit : Int32,
) -> Result[@engine.Fields, @engine.MatchError] {
  @engine.match_line_with_limit(program, line, step_limit)
}

///|
/// The value of a named field, or none when the pattern does not declare it.
pub fn field_value(fields : @engine.Fields, name : String) -> String? {
  fields.get(name)
}

///|
/// Number of fields in one match result.
pub fn field_total(fields : @engine.Fields) -> Int32 {
  fields.size()
}

///|
/// Render a match failure as one stable line.
pub fn describe_match_error(error : @engine.MatchError) -> String {
  @engine.describe_match_error(error)
}

///|
/// The field name at one index, in pattern order.
pub fn field_name(fields : @engine.Fields, index : Int32) -> String {
  fields.name_at(index)
}

///|
/// Try compiled programs in order and return the first one that matches.
pub fn match_first(
  programs : Array[@compile.Program],
  line : String,
) -> Result[@engine.FirstMatch, @engine.MatchError] {
  @engine.match_first(programs, line)
}

///|
/// Try compiled programs in order, with an explicit step budget per program.
pub fn match_first_with_limit(
  programs : Array[@compile.Program],
  line : String,
  step_limit : Int32,
) -> Result[@engine.FirstMatch, @engine.MatchError] {
  @engine.match_first_with_limit(programs, line, step_limit)
}

///|
/// Which program matched, counted from zero in the order it was tried.
pub fn first_pattern_index(hit : @engine.FirstMatch) -> Int32 {
  hit.first_pattern_index()
}

///|
/// The field table produced by the matching program.
pub fn first_fields(hit : @engine.FirstMatch) -> @engine.Fields {
  hit.first_matched_fields()
}

///|
/// Analyse a compiled program without running it.
pub fn analyze(program : @compile.Program) -> @compile.Analysis {
  @compile.analyze(program)
}

///|
/// Render a static finding as one stable line.
pub fn describe_issue(issue : @compile.Issue) -> String {
  @compile.describe_issue(issue)
}
