///|
/// Render one reference in a stable form.
fn render_reference(reference : PatternRef) -> String {
  match reference.field {
    Some(field) => "ref(" + reference.name + ":" + field + ")"
    None => "ref(" + reference.name + ")"
  }
}

///|
/// Render a parsed pattern to a stable, testable one-line form.
///
/// This is not the input syntax. It shows the segmentation instead, so a test can
/// see whether two neighbouring literals stayed apart and whether a field was
/// attached to the reference it belongs to.
pub fn render_pattern(pattern : Pattern) -> String {
  let mut rendered = ""
  let mut first = true
  for segment in pattern.segments {
    let piece = match segment {
      Literal(text) => "literal(" + text + ")"
      Ref(reference) => render_reference(reference)
    }
    if first {
      rendered = rendered + piece
      first = false
    } else {
      rendered = rendered + " " + piece
    }
  }
  rendered
}