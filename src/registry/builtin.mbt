///|
/// The curated built-in registry.
///
/// Every entry is written here, in bracket classes rather than backslash
/// shorthands, so the body text stays readable and identical across targets.
/// Families are added only when a corpus line exercises them: access logs first,
/// then the syslog prefix.
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
  registry.add("MONTH", "(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)")
  registry.add("MONTHDAY", "[ 0-9][0-9]")
  registry.add("TIME", "[0-9]{2}:[0-9]{2}:[0-9]{2}")
  registry.add("SYSLOGTIMESTAMP", "%{MONTH} +%{MONTHDAY} %{TIME}")
  registry.add("PROG", "[A-Za-z0-9_.-]+")
  registry.add("SYSLOGBASE", "%{SYSLOGTIMESTAMP} %{HOST} %{PROG}")
  registry
}
