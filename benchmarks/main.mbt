// Benchmark harness. Run one stage per invocation so an external timer measures the
// stage rather than process startup: `moon run benchmarks -- parse`.
//
// `noop` measures startup and dispatch so a stage number can be read net of it.
// Results are evidence for this repository, not a published throughput figure:
// docs/limits.md states that no such figure is published.

///|
fn bench_parse(iterations : Int32) -> Unit {
  let mut ok = 0
  let mut index = 0
  while index < iterations {
    match @src.parse("%{IP:client} %{WORD:method} %{STATUS:status}") {
      Ok(_) => ok = ok + 1
      Err(_) => ()
    }
    index = index + 1
  }
  println("stage parse ops=" + ok.to_string())
}

///|
fn bench_compile(iterations : Int32) -> Unit {
  let mut ok = 0
  let mut index = 0
  while index < iterations {
    match @src.compile_builtin("%{IP:client} %{WORD:method} %{STATUS:status}") {
      Ok(_) => ok = ok + 1
      Err(_) => ()
    }
    index = index + 1
  }
  println("stage compile ops=" + ok.to_string())
}

///|
fn bench_match(iterations : Int32) -> Unit {
  let program = match
    @src.compile_builtin("%{IP:client} %{WORD:method} %{STATUS:status}") {
    Ok(ready) => ready
    Err(_) => abort("bench setup: compile failed")
  }
  let mut ok = 0
  let mut index = 0
  while index < iterations {
    match @src.match_line(program, "10.0.0.7 GET 404") {
      Ok(_) => ok = ok + 1
      Err(_) => ()
    }
    index = index + 1
  }
  println("stage match ops=" + ok.to_string())
}

///|
fn bench_analysis(iterations : Int32) -> Unit {
  let program = match
    @src.compile_builtin("%{SYSLOGBASE} %{GREEDYDATA:message}") {
    Ok(ready) => ready
    Err(_) => abort("bench setup: compile failed")
  }
  let mut total = 0
  let mut index = 0
  while index < iterations {
    total = total + @src.analyze(program).issue_count()
    index = index + 1
  }
  println("stage analysis ops=" + total.to_string())
}

///|
fn bench_validate(iterations : Int32) -> Unit {
  let program = match
    @src.compile_builtin("%{IP:client} %{WORD:method} %{STATUS:status}") {
    Ok(ready) => ready
    Err(_) => abort("bench setup: compile failed")
  }
  let fields = match @src.match_line(program, "10.0.0.7 GET 404") {
    Ok(ready) => ready
    Err(_) => abort("bench setup: match failed")
  }
  let spec = @src.contract()
  spec.between("status", 100, 599)
  spec.one_of("method", ["GET", "POST", "PUT", "DELETE"])
  spec.min_length("client", 7)
  let mut total = 0
  let mut index = 0
  while index < iterations {
    total = total + @src.validate(fields, spec).length()
    index = index + 1
  }
  println("stage validate ops=" + total.to_string())
}

///|
fn bench_assemble(pairs : Int32, iterations : Int32) -> Unit {
  let lines : Array[String] = []
  let mut built = 0
  while built < pairs {
    lines.push("header " + built.to_string())
    lines.push("    frame " + built.to_string())
    built = built + 1
  }
  let mut total = 0
  let mut index = 0
  while index < iterations {
    total = total + @src.assemble(@src.assembler(), lines).length()
    index = index + 1
  }
  println("stage assemble ops=" + total.to_string())
}

///|
fn main {
  let args = @env.args()
  let mut stage = "all"
  if args.length() > 1 {
    stage = args[1]
  }
  if stage == "parse" {
    bench_parse(20000)
  } else if stage == "compile" {
    bench_compile(5000)
  } else if stage == "match" {
    bench_match(50000)
  } else if stage == "analysis" {
    bench_analysis(20000)
  } else if stage == "validate" {
    bench_validate(20000)
  } else if stage == "assemble" {
    bench_assemble(1000, 500)
  } else if stage == "noop" {
    println("stage noop ops=0")
  } else {
    bench_parse(2000)
    bench_compile(500)
    bench_match(2000)
    bench_analysis(2000)
    bench_validate(2000)
    bench_assemble(200, 50)
  }
}
