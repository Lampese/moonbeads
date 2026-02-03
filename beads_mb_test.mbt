///|
fn make_issue(
  id : String,
  status? : String = @moonissues.status_open,
  deps? : Array[String] = [],
  priority? : Int = 2,
  description? : String = "",
) -> @moonissues.Issue {
  let now : UInt64 = 0
  @moonissues.Issue::{
    id,
    title: id,
    description,
    status,
    priority,
    created_at: now,
    updated_at: now,
    deps: deps.copy(),
    notes: "",
  }
}

///|
test "normalize status variants" {
  assert_eq(@moonissues.normalize_status("OPEN"), Some(@moonissues.status_open))
  assert_eq(
    @moonissues.normalize_status("in-progress"),
    Some(@moonissues.status_in_progress),
  )
  assert_eq(
    @moonissues.normalize_status("done"),
    Some(@moonissues.status_closed),
  )
  assert_eq(@moonissues.normalize_status("wat"), None)
}

///|
test "next issue id increments" {
  let base = @moonissues.next_issue_id([], "title", "desc", 123)
  assert_true(base.strip_prefix("mi-") is Some(_))
  assert_eq(base.length(), 9)
  let issues = [make_issue(base)]
  let next = @moonissues.next_issue_id(issues, "title", "desc", 123)
  assert_true(next != base)
}

///|
test "dependency cycle detection" {
  let issues = [
    make_issue("mi-1", deps=["mi-2"]),
    make_issue("mi-2", deps=["mi-3"]),
    make_issue("mi-3"),
  ]
  assert_true(@moonissues.would_create_cycle(issues, "mi-3", "mi-1"))
  assert_true(!@moonissues.would_create_cycle(issues, "mi-1", "mi-3"))
}

///|
test "remove dep value" {
  let deps = @moonissues.remove_dep_value(["mi-2", "mi-3", "mi-2"], "mi-2")
  assert_eq(deps, ["mi-3"])
}

///|
test "ready requires closed deps" {
  let issues = [make_issue("mi-1"), make_issue("mi-2", deps=["mi-1"])]
  let status_map = @moonissues.build_status_map(issues)
  assert_true(!@moonissues.is_ready(issues[1], status_map))
  let done = [
    make_issue("mi-1", status=@moonissues.status_closed),
    make_issue("mi-2", deps=["mi-1"]),
  ]
  let done_map = @moonissues.build_status_map(done)
  assert_true(@moonissues.is_ready(done[1], done_map))
  let in_progress = [
    make_issue("mi-1", status=@moonissues.status_closed),
    make_issue("mi-2", status=@moonissues.status_in_progress, deps=["mi-1"]),
  ]
  let in_progress_map = @moonissues.build_status_map(in_progress)
  assert_true(@moonissues.is_ready(in_progress[1], in_progress_map))
}

///|
test "issue description roundtrip" {
  let issue = make_issue("mi-10", description="summary")
  let json = issue.to_json()
  let decoded : @moonissues.Issue = @json.from_json(json)
  assert_eq(decoded.description, "summary")
}
