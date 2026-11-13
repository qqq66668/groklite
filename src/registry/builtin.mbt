///|
/// The curated built-in registry.
///
/// Every entry is written here, in bracket classes rather than backslash
/// shorthands, so the body text stays readable and identical across targets.
/// Families are added only when a corpus line exercises them.
pub fn builtin() -> Registry {
  let registry = empty()
  registry.add("WORD", "[A-Za-z0-9_]+")
  registry.add("NOTSPACE", "[^ ]+")
  registry.add("NUMBER", "[0-9]+")
  registry.add("INT", "[+-]?[0-9]+")
  registry.add("SPACE", " +")
  registry.add("STATUS", "[0-9]{3}")
  registry.add("USER", "[A-Za-z0-9_.-]+")
  registry.add("HOST", "[A-Za-z0-9_.-]+")
  registry.add("IP", "[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}")
  registry.add("IPORHOST", "(?:%{IP}|%{HOST})")
  registry
}