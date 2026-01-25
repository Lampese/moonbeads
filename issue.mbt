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
  status : String
  priority : Int
  created_at : UInt64
  updated_at : UInt64
  deps : Array[String]
  notes : String
} derive(ToJson, FromJson, Show, Eq)

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
  if issue.status != status_open {
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
