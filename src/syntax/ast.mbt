///|
/// One element of a parsed pattern.
///
/// A pattern is a sequence of segments that must match in order. Literal text
/// matches itself; a reference matches one named rule and contributes the matched
/// text to the result when it carries a field name.
pub enum Segment {
  Literal(String)
  Ref(PatternRef)
}

///|
/// A reference to a named rule, written `%{NAME}` or `%{NAME:field}`.
pub struct PatternRef {
  name : String
  field : String?
}

///|
/// A pattern parsed into its ordered segments.
pub struct Pattern {
  segments : Array[Segment]
}

///|
/// Number of top-level segments in the pattern.
pub fn Pattern::segment_count(self : Pattern) -> Int {
  self.segments.length()
}