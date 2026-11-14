///|
/// Why a rule body could not be resolved into a fully expanded body.
pub enum RegistryError {
  UnknownPattern(String)
  Cycle(String)
  DepthExceeded(Int32)
  NestedFieldUnsupported(Int32)
  UnterminatedReference(Int32)
}

///|
/// An ordered collection of named rule bodies.
///
/// Insertion order is preserved and lookup is a linear scan over two parallel
/// arrays. A curated registry holds tens of entries, so a scan keeps behaviour
/// identical on every target without depending on a hash map.
pub struct Registry {
  names : Array[String]
  bodies : Array[String]
}

///|
/// An empty registry.
pub fn empty() -> Registry {
  let registry : Registry = { names: [], bodies: [], }
  registry
}

///|
/// Append one entry. The first entry with a given name wins on lookup, so a
/// shadowed duplicate is dead weight rather than a silent override.
pub fn Registry::add(self : Registry, name : String, body : String) -> Unit {
  self.names.push(name)
  self.bodies.push(body)
}

///|
/// Number of stored entries, including any shadowed duplicates.
pub fn Registry::size(self : Registry) -> Int32 {
  self.names.length()
}

///|
fn find(registry : Registry, name : String) -> (Bool, String) {
  let total = registry.names.length()
  let mut index = 0
  let mut hit = false
  let mut body = ""
  while index < total {
    if !hit && registry.names[index] == name {
      hit = true
      body = registry.bodies[index]
    }
    index = index + 1
  }
  (hit, body)
}

///|
fn contains_name(path : Array[String], name : String) -> Bool {
  let mut index = 0
  let mut hit = false
  while index < path.length() {
    if path[index] == name {
      hit = true
    }
    index = index + 1
  }
  hit
}

///|
fn append_name(path : Array[String], name : String) -> Array[String] {
  let next : Array[String] = []
  for item in path {
    next.push(item)
  }
  next.push(name)
  next
}

///|
fn expand_body(
  registry : Registry,
  body : String,
  path : Array[String],
  max_depth : Int32,
) -> Result[String, RegistryError] {
  if path.length() > max_depth {
    return Err(DepthExceeded(max_depth))
  }
  let mut result = ""
  let mut literal : StringBuilder = StringBuilder()
  let mut name_buf : StringBuilder = StringBuilder()
  let mut in_reference = false
  let mut pending_percent = false
  let mut ref_offset = 0
  let mut offset = 0
  for c in body {
    if !in_reference {
      if pending_percent {
        pending_percent = false
        if c == '{' {
          in_reference = true
          name_buf = StringBuilder()
          ref_offset = offset - 1
        } else {
          literal.write_char('%')
          if c == '%' {
            pending_percent = true
          } else {
            literal.write_char(c)
          }
        }
      } else if c == '%' {
        pending_percent = true
      } else {
        literal.write_char(c)
      }
    } else if c == '}' {
      let name = name_buf.to_string()
      result = result + literal.to_string()
      literal = StringBuilder()
      let outcome = expand_reference(registry, name, path, max_depth)
      match outcome {
        Ok(text) => result = result + text
        Err(error) => return Err(error)
      }
      in_reference = false
    } else if c == ':' {
      return Err(NestedFieldUnsupported(ref_offset))
    } else {
      name_buf.write_char(c)
    }
    offset = offset + 1
  }
  if in_reference {
    return Err(UnterminatedReference(ref_offset))
  }
  if pending_percent {
    literal.write_char('%')
  }
  result = result + literal.to_string()
  Ok(result)
}

///|
fn expand_reference(
  registry : Registry,
  name : String,
  path : Array[String],
  max_depth : Int32,
) -> Result[String, RegistryError] {
  if contains_name(path, name) {
    return Err(Cycle(name))
  }
  let (hit, body) = find(registry, name)
  if !hit {
    return Err(UnknownPattern(name))
  }
  expand_body(registry, body, append_name(path, name), max_depth)
}

///|
/// Expand one named pattern into a body with no remaining references.
///
/// A field name on a nested reference is an error rather than a silent drop: a
/// caller who writes one is asking for a capture this design cannot deliver.
pub fn resolve(
  registry : Registry,
  name : String,
) -> Result[String, RegistryError] {
  let path : Array[String] = []
  expand_reference(registry, name, path, 32)
}

///|
/// Render a registry failure as one stable line.
pub fn describe_registry_error(error : RegistryError) -> String {
  match error {
    UnknownPattern(name) => "unknown pattern: " + name
    Cycle(name) => "pattern cycle through: " + name
    DepthExceeded(limit) =>
      "pattern expansion exceeded depth limit: " + limit.to_string()
    NestedFieldUnsupported(offset) =>
      "field name on a nested reference at offset " +
      offset.to_string() +
      " is not supported"
    UnterminatedReference(offset) =>
      "unterminated reference at offset " + offset.to_string()
  }
}
