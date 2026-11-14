///|
/// Compile pattern text against the curated built-in registry.
///
/// A caller that holds pattern text and wants a program uses this entry point;
/// the curated subset is what the text resolves against.
pub fn compile_builtin(
  pattern_text : String,
) -> Result[@compile.Program, @compile.CompileError] {
  @compile.compile(@registry.builtin(), pattern_text)
}
