///|
let legacy_dir = ".beads"

///|
let legacy_issues_file = "issues.jsonl"

///|
let legacy_backup_file = "issues.jsonl.bak"

///|
let new_dir = ".issues"

///|
async fn maybe_migrate_legacy_store() -> Result[Bool, String] {
  let new_issues_path = join_path(new_dir, legacy_issues_file)
  if @fs.exists(new_issues_path) {
    return Ok(false)
  }
  if !@fs.exists(legacy_dir) {
    return Ok(false)
  }
  let legacy_path = join_path(legacy_dir, legacy_issues_file)
  let backup_path = join_path(legacy_dir, legacy_backup_file)
  let content = if @fs.exists(legacy_path) {
    @fs.read_file(legacy_path).text()
  } else if @fs.exists(backup_path) {
    @fs.read_file(backup_path).text()
  } else {
    ""
  }
  let issues = parse_legacy_issues(content)
  let store = Store::new(beads_dir=new_dir)
  store.ensure_workspace()
  store.save_issues(issues)
  try @fs.rmdir(legacy_dir, recursive=true) catch {
    err => return Err("failed to remove legacy .beads: \{err}")
  } noraise {
    _ => ()
  }
  Ok(true)
}

///|
fn parse_legacy_issues(content : String) -> Array[Issue] {
  let issues : Array[Issue] = []
  for line in content.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let issue = parse_legacy_issue_line(trimmed.to_string())
    match issue {
      Some(value) => issues.push(value)
      None => ()
    }
  }
  issues
}

///|
fn parse_legacy_issue_line(line : String) -> Issue? {
  try @json.parse(line) catch {
    _ => None
  } noraise {
    json => parse_legacy_issue(json)
  }
}

///|
fn parse_legacy_issue(json : Json) -> Issue? {
  match json {
    Object(obj) => parse_legacy_issue_object(obj)
    _ => None
  }
}

///|
fn parse_legacy_issue_object(obj : Map[String, Json]) -> Issue? {
  let id = get_string(obj, "id")
  if id.is_empty() {
    return None
  }
  let title = get_string(obj, "title")
  if title.is_empty() {
    return None
  }
  let status_raw = get_string(obj, "status")
  let status = match normalize_status(status_raw) {
    Some(value) => value
    None => if status_raw.is_empty() { status_open } else { status_raw }
  }
  let priority = get_int(obj, "priority", 2)
  let created_at = get_uint64(obj, "created_at")
  let updated_at = get_uint64(obj, "updated_at")
  let deps = get_string_array(obj, "deps")
  let notes = get_string(obj, "notes")
  let description = get_string(obj, "description")
  Some(Issue::{
    id,
    title,
    description,
    status,
    priority,
    created_at,
    updated_at,
    deps,
    notes,
  })
}

///|
fn get_string(obj : Map[String, Json], key : String) -> String {
  match obj.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn get_int(obj : Map[String, Json], key : String, fallback : Int) -> Int {
  match obj.get(key) {
    Some(value) => parse_int_json(value, fallback)
    None => fallback
  }
}

///|
fn parse_int_json(value : Json, fallback : Int) -> Int {
  match value {
    Number(num, repr~) =>
      match repr {
        Some(text) => parse_int_string(text, fallback)
        None => num.to_int()
      }
    String(text) => parse_int_string(text, fallback)
    _ => fallback
  }
}

///|
fn parse_int_string(text : String, fallback : Int) -> Int {
  try @strconv.parse_int(text, base=10) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn get_uint64(obj : Map[String, Json], key : String) -> UInt64 {
  match obj.get(key) {
    Some(value) => parse_uint64_json(value)
    None => 0
  }
}

///|
fn parse_uint64_json(value : Json) -> UInt64 {
  match value {
    Number(num, repr~) =>
      match repr {
        Some(text) => parse_uint64_string(text)
        None => if num < 0.0 { 0 } else { num.to_uint64() }
      }
    String(text) => parse_uint64_string(text)
    _ => 0
  }
}

///|
fn parse_uint64_string(text : String) -> UInt64 {
  try @strconv.parse_uint64(text, base=10) catch {
    _ => 0
  } noraise {
    value => value
  }
}

///|
fn get_string_array(obj : Map[String, Json], key : String) -> Array[String] {
  match obj.get(key) {
    Some(Array(values)) => parse_string_array(values)
    _ => []
  }
}

///|
fn parse_string_array(values : Array[Json]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    match value {
      String(text) => out.push(text)
      _ => ()
    }
  }
  out
}
