///|
let onboard_section =
  #|## Moonissues
  #|
  #|This project uses moonissues for issue tracking.
  #|Run `moonissues prime` for workflow context.
  #|

///|
let onboard_file =
  #|# AGENTS.md
  #|
  #|This project uses moonissues for issue tracking.
  #|Run `moonissues prime` for workflow context.
  #|

///|
let legacy_onboard_section =
  #|## Moonbead
  #|
  #|This project uses moonbead for issue tracking.
  #|Run `moonbead prime` for workflow context.
  #|

///|
let legacy_onboard_file =
  #|# AGENTS.md
  #|
  #|This project uses moonbead for issue tracking.
  #|Run `moonbead prime` for workflow context.
  #|

///|
let prime_prompt =
  #|# moonissues prime
  #|
  #|Moonissues is a local issue tracker for AI-assisted work.
  #|IDs: mi-1a2b3c4d
  #|
  #|Workflow:
  #|1. Pick work: moonissues ready --json
  #|2. Create issues for new work: moonissues create "..." --description "..."
  #|3. Mark in progress: moonissues status <id> in_progress
  #|4. Update details: moonissues update <id> --description "..." --notes "..." --priority 1
  #|5. Link dependencies: moonissues dep add <child> <parent>
  #|6. Close when done: moonissues close <id>
  #|7. Commit moonissues data updates with code changes
  #|
  #|Useful:
  #|- moonissues list [--status <status>] [--ready] [--all]
  #|- moonissues show <id>
  #|- Use --json for machine parsing
  #|
  #|Notes:
  #|- list hides closed by default; add --all to include them.
  #|- If lock is stale, retry with --force.
  #|- Do not read or edit moonissues storage directly; use moonissues for all operations.
  #|- When you say "Next steps" to user, you should create issues for these next steps, and follow bd workflow to continue.
  #|- When creating issue, write a detailed handoff in description so you may start work on it with zero context.
  #|- When there's no ready tasks, you should carefully review the open epic issues. Don't close epic issue without reviewing. After review you decide if need update plan. If update needed, re-plan it use moonissues workflow.
  #|

///|
fn replace_legacy_onboard(content : String) -> String? {
  if content.contains(legacy_onboard_section) {
    return Some(
      content.replace_all(old=legacy_onboard_section, new=onboard_section),
    )
  }
  if content.contains(legacy_onboard_file) {
    return Some(content.replace_all(old=legacy_onboard_file, new=onboard_file))
  }
  if content.trim() == legacy_onboard_file.trim() {
    return Some(onboard_file)
  }
  None
}

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
    match replace_legacy_onboard(content) {
      Some(updated) => {
        @fs.write_file(path, updated, create=0o644, truncate=true)
        return Some("updated AGENTS.md")
      }
      None => ()
    }
    if content.contains("moonissues") || content.contains("moonissues prime") {
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
