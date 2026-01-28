///|
let onboard_section =
  #|## Moonbead
  #|
  #|This project uses moonbead for issue tracking.
  #|Run `moonbead prime` for workflow context.
  #|

///|
let onboard_file =
  #|# AGENTS.md
  #|
  #|This project uses moonbead for issue tracking.
  #|Run `moonbead prime` for workflow context.
  #|

///|
let prime_prompt =
  #|# moonbead prime
  #|
  #|Moonbead is a local JSONL issue tracker for AI-assisted work.
  #|Data: .beads/issues.jsonl  Lock: .beads/lock  IDs: mb-1
  #|
  #|Workflow:
  #|1. Pick work: moonbead ready --json
  #|2. Create issues for new work: moonbead create "..." --description "..."
  #|3. Mark in progress: moonbead status <id> in_progress
  #|4. Update details: moonbead update <id> --description "..." --notes "..." --priority 1
  #|5. Link dependencies: moonbead dep add <child> <parent>
  #|6. Close when done: moonbead close <id>
  #|7. Commit .beads/issues.jsonl with code changes
  #|
  #|Useful:
  #|- moonbead list [--status <status>] [--ready] [--all]
  #|- moonbead show <id>
  #|- Use --json for machine parsing
  #|
  #|Notes:
  #|- list hides closed by default; add --all to include them.
  #|- If lock is stale, retry with --force.
  #|

///|
async fn cmd_onboard(_opts : GlobalOptions) -> Unit {
  @stdio.stdout.write(onboard_section)
}

///|
async fn cmd_prime(_opts : GlobalOptions) -> Unit {
  @stdio.stdout.write(prime_prompt)
}

///|
async fn ensure_agents_doc() -> String? {
  let path = "AGENTS.md"
  if @fs.exists(path) {
    let content = @fs.read_file(path).text()
    if content.contains("moonbead") || content.contains("moonbead prime") {
      return None
    }
    let updated = if content.trim().is_empty() {
      onboard_file
    } else {
      content + "\n\n" + onboard_section
    }
    @fs.write_file(path, updated, create=0o644, truncate=true)
    return Some("updated AGENTS.md")
  }
  @fs.write_file(path, onboard_file, create=0o644, truncate=true)
  Some("created AGENTS.md")
}
