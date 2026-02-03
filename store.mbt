///|
let id_prefix = "mi-"

///|
pub struct Store {
  beads_dir : String
  issues_path : String
  backup_path : String
  tmp_path : String
  lock_path : String
}

///|
pub fn Store::new(beads_dir? : String = ".beads") -> Store {
  let issues_path = join_path(beads_dir, "issues.jsonl")
  let backup_path = join_path(beads_dir, "issues.jsonl.bak")
  let tmp_path = join_path(beads_dir, "issues.jsonl.tmp")
  let lock_path = join_path(beads_dir, "lock")
  { beads_dir, issues_path, backup_path, tmp_path, lock_path }
}

///|
pub fn Store::lock_path(self : Store) -> String {
  self.lock_path
}

///|
pub fn Store::issues_path(self : Store) -> String {
  self.issues_path
}

///|
pub fn Store::backup_path(self : Store) -> String {
  self.backup_path
}

///|
pub fn Store::tmp_path(self : Store) -> String {
  self.tmp_path
}

///|
pub async fn Store::ensure_workspace(self : Store) -> Unit {
  try @fs.mkdir(self.beads_dir, permission=0o755, recursive=true) catch {
    @os_error.OSError(_) as err if err.is_EEXIST() => ()
    err => raise err
  } noraise {
    _ => ()
  }
}

///|
pub async fn Store::load_issues(self : Store) -> Array[Issue] {
  try load_issues_from_path(self.issues_path) catch {
    _ =>
      if @fs.exists(self.backup_path) {
        try load_issues_from_path(self.backup_path) catch {
          _ => []
        } noraise {
          issues => issues
        }
      } else {
        []
      }
  } noraise {
    issues => issues
  }
}

///|
pub async fn Store::save_issues(self : Store, issues : Array[Issue]) -> Unit {
  let lines = issues.map(issue => issue.to_json().stringify())
  let body = if lines.length() == 0 { "" } else { lines.join("\n") + "\n" }
  @fs.write_file(self.tmp_path, body, create=0o644, truncate=true)
  if @fs.exists(self.issues_path) {
    let current = @fs.read_file(self.issues_path)
    @fs.write_file(
      self.backup_path,
      current.binary(),
      create=0o644,
      truncate=true,
    )
  }
  @fs.write_file(self.issues_path, body, create=0o644, truncate=true)
  try @fs.remove(self.tmp_path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
async fn load_issues_from_path(path : String) -> Array[Issue] {
  if !@fs.exists(path) {
    return []
  }
  let data = @fs.read_file(path)
  let content = data.text()
  let issues = []
  for line in content.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let json = @json.parse(trimmed)
    let issue : Issue = @json.from_json(json)
    issues.push(issue)
  }
  issues
}

///|
pub fn next_issue_id(
  issues : Array[Issue],
  title : String,
  description : String,
  created_at : UInt64,
) -> String {
  for nonce = 0 {
    let payload = "\{title}\n\{description}\n\{created_at.to_string()}\n\{nonce}"
    let bytes = @utf8.encode(payload)
    let digest = @crypto.sha256(bytes)
    let short_bytes = FixedArray::makei(4, i => digest[i])
    let short = @crypto.bytes_to_hex_string(short_bytes)
    let id = "\{id_prefix}\{short}"
    if !issues.any(issue => issue.id == id) {
      return id
    }
    continue nonce + 1
  } else {
    "\{id_prefix}00000000"
  }
}

///|
pub fn find_issue_index(issues : Array[Issue], id : String) -> Int? {
  for i, issue in issues {
    if issue.id == id {
      return Some(i)
    }
  }
  None
}

///|
pub fn build_status_map(issues : Array[Issue]) -> Map[String, String] {
  let map : Map[String, String] = {}
  for issue in issues {
    map[issue.id] = issue.status
  }
  map
}
