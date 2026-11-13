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
pub fn segment_count(pattern : @syntax.Pattern) -> Int {
  pattern.segment_count()
}

///|
/// The curated built-in registry.
pub fn builtin_registry() -> @registry.Registry {
  @registry.builtin()
}

///|
/// Expand one named pattern into a body with no remaining references.
pub fn resolve_pattern(registry : @registry.Registry, name : String) -> Result[String, @registry.RegistryError] {
  @registry.resolve(registry, name)
}

///|
/// Render a registry failure as one stable line.
pub fn describe_registry_error(error : @registry.RegistryError) -> String {
  @registry.describe_registry_error(error)
}

///|
/// Compile pattern text into a program and its field table.
pub fn compile(registry : @registry.Registry, pattern_text : String) -> Result[@compile.Program, @compile.CompileError] {
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