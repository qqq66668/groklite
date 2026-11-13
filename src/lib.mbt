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