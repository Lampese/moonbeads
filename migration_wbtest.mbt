///|
test "legacy schema migration parse" {
  let line = "{\"id\":\"bd-1\",\"title\":\"hello\",\"status\":\"open\",\"priority\":2,\"created_at\":\"1700000000000\",\"updated_at\":\"1700000000000\",\"deps\":[],\"notes\":\"\"}"
  let issues = parse_legacy_issues(line + "\n")
  assert_eq(issues.length(), 1)
  let issue = issues[0]
  assert_eq(issue.id, "bd-1")
  assert_eq(issue.description, "")
  assert_eq(issue.created_at, 1700000000000UL)
  assert_eq(issue.updated_at, 1700000000000UL)
}
