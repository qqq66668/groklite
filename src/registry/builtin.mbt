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
  registry.add("DATA", ".*")
  registry.add("GREEDYDATA", ".*")
  registry.add("QS", "\"[^\"]*\"")
  registry.add("QUOTEDSTRING", "%{QS}")
  registry.add("POSINT", "[1-9][0-9]*")
  registry.add("BASE10NUM", "-?[0-9]+([.][0-9]+)?")
  registry.add("FLOAT", "-?[0-9]+[.][0-9]+")
  registry.add("BASE16NUM", "(0[xX])?[0-9A-Fa-f]+")
  registry.add("IPV4", "[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}")
  registry.add("IPV6", "([0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}")
  registry.add("HOSTNAME", "[A-Za-z0-9][A-Za-z0-9.-]*")
  registry.add("HOSTPORT", "%{HOSTNAME}:%{POSINT}")
  registry.add("URIPATH", "/[A-Za-z0-9_.+/-]*")
  registry.add(
    "TIMESTAMP_ISO8601", "[0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9]{2}:[0-9]{2}:[0-9]{2}",
  )
  registry.add("YEAR", "[0-9]{4}")
  registry.add("DAY", "(Mon|Tue|Wed|Thu|Fri|Sat|Sun)")
  registry.add("MONTHNUM", "(0?[1-9]|1[0-2])")
  registry.add(
    "HTTPDATE", "[0-9]{2}/[A-Za-z]{3}/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}",
  )
  registry.add("LOGLEVEL", "(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)")
  registry.add(
    "UUID", "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
  )
  registry.add("MAC", "([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}")
  registry.add("EMAILADDRESS", "[A-Za-z0-9_.+-]+@[A-Za-z0-9.-]+")
  registry.add("TZ", "(UTC|[+-][0-9]{2}:?[0-9]{2})")
  registry.add("SYSLOGHOST", "%{IPORHOST}")
  registry
}
