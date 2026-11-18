///|
test "the built-in registry ships forty curated patterns" {
  assert_eq(@registry.builtin().size(), 40)
}

///|
test "a leaf pattern resolves to its own class" {
  match @registry.resolve(@registry.builtin(), "WORD") {
    Ok(text) => assert_eq(text, "[A-Za-z0-9_]+")
    Err(error) => abort(@registry.describe_registry_error(error))
  }
}

///|
test "nested references disappear from the expanded body" {
  match @registry.resolve(@registry.builtin(), "IPORHOST") {
    Ok(text) =>
      assert_eq(
        text, "(?:[0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}|[A-Za-z0-9_.-]+)",
      )
    Err(error) => abort(@registry.describe_registry_error(error))
  }
}

///|
test "an unknown name is reported with the name" {
  match @registry.resolve(@registry.builtin(), "NOSUCH") {
    Ok(_) => abort("expected an unknown pattern error")
    Err(error) =>
      assert_eq(
        @registry.describe_registry_error(error),
        "unknown pattern: NOSUCH",
      )
  }
}

///|
test "a reference cycle is reported instead of recursing forever" {
  let registry = @registry.empty()
  registry.add("A", "%{B}")
  registry.add("B", "%{A}")
  match @registry.resolve(registry, "A") {
    Ok(_) => abort("expected a cycle error")
    Err(error) =>
      assert_eq(
        @registry.describe_registry_error(error),
        "pattern cycle through: A",
      )
  }
}

///|
test "a chain deeper than the limit is an error, not a crash" {
  let registry = @registry.empty()
  let mut index = 0
  while index < 40 {
    let next = index + 1
    registry.add("L" + index.to_string(), "%{L" + next.to_string() + "}")
    index = index + 1
  }
  registry.add("L40", "end")
  match @registry.resolve(registry, "L0") {
    Ok(_) => abort("expected a depth error")
    Err(error) =>
      assert_eq(
        @registry.describe_registry_error(error),
        "pattern expansion exceeded depth limit: 32",
      )
  }
}

///|
test "a field on a nested reference is refused, not silently dropped" {
  let registry = @registry.empty()
  registry.add("OUTER", "%{IP:client}")
  registry.add("IP", "x")
  match @registry.resolve(registry, "OUTER") {
    Ok(_) => abort("expected a nested field error")
    Err(error) =>
      assert_eq(
        @registry.describe_registry_error(error),
        "field name on a nested reference at offset 0 is not supported",
      )
  }
}

///|
test "an unterminated reference inside a body is reported" {
  let registry = @registry.empty()
  registry.add("BROKEN", "%{IP")
  match @registry.resolve(registry, "BROKEN") {
    Ok(_) => abort("expected an unterminated reference error")
    Err(error) =>
      assert_eq(
        @registry.describe_registry_error(error),
        "unterminated reference at offset 0",
      )
  }
}

///|
test "literal text survives expansion, including a trailing percent" {
  let registry = @registry.empty()
  registry.add("PREFIXED", "status=%{STATUS} 50%")
  registry.add("STATUS", "[0-9]{3}")
  match @registry.resolve(registry, "PREFIXED") {
    Ok(text) => assert_eq(text, "status=[0-9]{3} 50%")
    Err(error) => abort(@registry.describe_registry_error(error))
  }
}
