///|
pub let status_open = "open"

///|
pub let status_in_progress = "in_progress"

///|
pub let status_blocked = "blocked"

///|
pub let status_closed = "closed"

///|
pub(all) struct Issue {
  id : String
  title : String
  description : String
  status : String
  priority : Int
  created_at : UInt64
  updated_at : UInt64
  deps : Array[String]
  notes : String
} derive(ToJson, Show, Eq)

///|
fn[T : @json.FromJson] get_field(
  obj : Map[String, Json],
  path : @json.JsonPath,
  key : String,
) -> T raise @json.JsonDecodeError {
  match obj.get(key) {
    Some(value) => @json.from_json(value, path=path.add_key(key))
    None => raise @json.JsonDecodeError((path.add_key(key), "missing field"))
  }
}

///|
fn get_optional_string(
  obj : Map[String, Json],
  path : @json.JsonPath,
  key : String,
) -> String raise @json.JsonDecodeError {
  match obj.get(key) {
    Some(value) => @json.from_json(value, path=path.add_key(key))
    None => ""
  }
}

///|
pub impl @json.FromJson for Issue with from_json(json, path) {
  match json {
    Object(obj) => {
      let id : String = get_field(obj, path, "id")
      let title : String = get_field(obj, path, "title")
      let description : String = get_optional_string(obj, path, "description")
      let status : String = get_field(obj, path, "status")
      let priority : Int = get_field(obj, path, "priority")
      let created_at : UInt64 = get_field(obj, path, "created_at")
      let updated_at : UInt64 = get_field(obj, path, "updated_at")
      let deps : Array[String] = get_field(obj, path, "deps")
      let notes : String = get_field(obj, path, "notes")
      Issue::{
        id,
        title,
        description,
        status,
        priority,
        created_at,
        updated_at,
        deps,
        notes,
      }
    }
    _ =>
      raise @json.JsonDecodeError((path, "Issue::from_json: expected object"))
  }
}

///|
pub fn normalize_status(value : String) -> String? {
  let cleaned = value.trim().to_lower()
  match cleaned {
    "open" => Some(status_open)
    "in_progress" | "in-progress" | "inprogress" => Some(status_in_progress)
    "blocked" => Some(status_blocked)
    "closed" | "done" => Some(status_closed)
    _ => None
  }
}

///|
pub fn is_ready(issue : Issue, status_by_id : Map[String, String]) -> Bool {
  if issue.status != status_open && issue.status != status_in_progress {
    return false
  }
  if issue.deps.length() == 0 {
    return true
  }
  for dep in issue.deps {
    match status_by_id.get(dep) {
      Some(status) => if status != status_closed { return false }
      None => return false
    }
  }
  true
}
