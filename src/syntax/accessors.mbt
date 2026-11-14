///|
/// The segment at an index. Out-of-range indices are a programming error.
pub fn Pattern::segment_at(self : Pattern, index : Int32) -> Segment {
  self.segments[index]
}

///|
/// The rule name a reference points at.
pub fn PatternRef::ref_name(self : PatternRef) -> String {
  self.name
}

///|
/// The field name a reference carries, when it carries one.
pub fn PatternRef::ref_field(self : PatternRef) -> String? {
  self.field
}
