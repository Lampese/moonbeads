///|
fn make_issue(
  id : String,
  status? : String = @moonbead.status_open,
  deps? : Array[String] = [],
  priority? : Int = 2,
  description? : String = "",
) -> @moonbead.Issue {
  let now : UInt64 = 0
  @moonbead.Issue::{
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
  assert_eq(@moonbead.normalize_status("OPEN"), Some(@moonbead.status_open))
  assert_eq(
    @moonbead.normalize_status("in-progress"),
    Some(@moonbead.status_in_progress),
  )
  assert_eq(@moonbead.normalize_status("done"), Some(@moonbead.status_closed))
  assert_eq(@moonbead.normalize_status("wat"), None)
}

///|
test "next issue id increments" {
  let issues = [make_issue("mb-2"), make_issue("bd-9"), make_issue("oops")]
  assert_eq(@moonbead.next_issue_id(issues), "mb-10")
}

///|
test "dependency cycle detection" {
  let issues = [
    make_issue("mb-1", deps=["mb-2"]),
    make_issue("mb-2", deps=["mb-3"]),
    make_issue("mb-3"),
  ]
  assert_true(@moonbead.would_create_cycle(issues, "mb-3", "mb-1"))
  assert_true(!@moonbead.would_create_cycle(issues, "mb-1", "mb-3"))
}

///|
test "remove dep value" {
  let deps = @moonbead.remove_dep_value(["mb-2", "mb-3", "mb-2"], "mb-2")
  assert_eq(deps, ["mb-3"])
}

///|
test "ready requires closed deps" {
  let issues = [make_issue("mb-1"), make_issue("mb-2", deps=["mb-1"])]
  let status_map = @moonbead.build_status_map(issues)
  assert_true(!@moonbead.is_ready(issues[1], status_map))
  let done = [
    make_issue("mb-1", status=@moonbead.status_closed),
    make_issue("mb-2", deps=["mb-1"]),
  ]
  let done_map = @moonbead.build_status_map(done)
  assert_true(@moonbead.is_ready(done[1], done_map))
  let in_progress = [
    make_issue("mb-1", status=@moonbead.status_closed),
    make_issue("mb-2", status=@moonbead.status_in_progress, deps=["mb-1"]),
  ]
  let in_progress_map = @moonbead.build_status_map(in_progress)
  assert_true(@moonbead.is_ready(in_progress[1], in_progress_map))
}

///|
test "issue description roundtrip" {
  let issue = make_issue("mb-10", description="summary")
  let json = issue.to_json()
  let decoded : @moonbead.Issue = @json.from_json(json)
  assert_eq(decoded.description, "summary")
}
