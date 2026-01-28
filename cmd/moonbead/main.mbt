///|
struct GlobalOptions {
  json : Bool
  force : Bool
  color : Bool
}

///|
struct ListOptions {
  status : String?
  priority : Int?
  ready_only : Bool
  search : String?
  sort_priority : Bool
  all : Bool
}

///|
struct UpdateOptions {
  title : String?
  notes : String?
  append_notes : String?
  priority : Int?
}

///|
struct CreateOptions {
  title : String
  priority : Int
  notes : String
}

///|
struct ActionPayload {
  action : String
  id : String?
  path : String?
} derive(ToJson)

///|
async fn main {
  let args = @env.args()
  run(args) catch {
    err => @stdio.stderr.write("error: \{err}\n")
  }
}

///|
async fn run(args : Array[String]) -> Unit {
  let (opts, rest) = parse_global_options(args)
  match rest {
    [_] | [_, "--help"] | [_, "-h"] => print_usage()
    [_, "init"] => cmd_init(opts)
    [_, "create", .. title_parts] => cmd_create(opts, title_parts)
    [_, "list", .. list_args] => cmd_list(opts, list_args)
    [_, "ready"] => cmd_ready(opts)
    [_, "onboard"] => cmd_onboard(opts)
    [_, "prime"] => cmd_prime(opts)
    [_, "show", id] => cmd_show(opts, id)
    [_, "close", id] => cmd_set_status(opts, id, @tracker.status_closed)
    [_, "status", id, status] => cmd_set_status(opts, id, status)
    [_, "update", id, .. update_args] => cmd_update(opts, id, update_args)
    [_, "delete", id] => cmd_delete(opts, id)
    [_, "dep", "add", child, parent] => cmd_dep_add(opts, child, parent)
    [_, "dep", "remove", child, parent] => cmd_dep_remove(opts, child, parent)
    _ => print_usage()
  }
}

///|
async fn cmd_init(opts : GlobalOptions) -> Unit {
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      if !@fs.exists(store.issues_path()) {
        store.save_issues([])
      }
      ()
    },
    force=opts.force,
  )
  match result {
    Some(_) => {
      let doc_change = ensure_agents_doc()
      if opts.json {
        write_json_action("init", path=store.issues_path())
      } else {
        @stdio.stdout.write("initialized \{store.issues_path()}\n")
        match doc_change {
          Some(message) => @stdio.stdout.write("\{message}\n")
          None => ()
        }
      }
    }
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_create(opts : GlobalOptions, args : ArrayView[String]) -> Unit {
  let create_opts = match parse_create_args(args) {
    Ok(opts) => opts
    Err(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      return
    }
  }
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      let now = @env.now()
      let issue = @tracker.Issue::{
        id: @tracker.next_issue_id(issues),
        title: create_opts.title,
        status: @tracker.status_open,
        priority: create_opts.priority,
        created_at: now,
        updated_at: now,
        deps: [],
        notes: create_opts.notes,
      }
      issues.push(issue)
      store.save_issues(issues)
      issue
    },
    force=opts.force,
  )
  match result {
    Some(issue) =>
      if opts.json {
        write_issue_json(issue)
      } else {
        @stdio.stdout.write("\{issue.id}\n")
      }
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_list(opts : GlobalOptions, args : ArrayView[String]) -> Unit {
  let store = @tracker.Store::new()
  let issues = store.load_issues()
  let list_opts = match parse_list_args(args) {
    Ok(opts) => opts
    Err(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      return
    }
  }
  if issues.length() == 0 {
    if !opts.json {
      @stdio.stdout.write("no issues\n")
    }
    return
  }
  let mut filtered = issues
  if list_opts.sort_priority {
    let sorted = issues.copy()
    sorted.sort_by(compare_priority_then_id)
    filtered = sorted
  }
  match list_opts.status {
    Some(status) => filtered = filtered.filter(issue => issue.status == status)
    None =>
      if !list_opts.all {
        filtered = filtered.filter(issue => issue.status !=
          @tracker.status_closed)
      }
  }
  match list_opts.priority {
    Some(priority) =>
      filtered = filtered.filter(issue => issue.priority == priority)
    None => ()
  }
  match list_opts.search {
    Some(search) => {
      let needle = search.to_lower()
      filtered = filtered.filter(issue => {
        let title = issue.title.to_lower()
        let notes = issue.notes.to_lower()
        title.contains(needle) || notes.contains(needle)
      })
    }
    None => ()
  }
  if list_opts.ready_only {
    let status_map = @tracker.build_status_map(issues)
    filtered = filtered.filter(issue => @tracker.is_ready(issue, status_map))
  }
  if filtered.length() == 0 {
    if !opts.json {
      @stdio.stdout.write("no matching issues\n")
    }
    return
  }
  if opts.json {
    for issue in filtered {
      write_issue_json(issue)
    }
  } else {
    for issue in filtered {
      @stdio.stdout.write(format_issue_line(issue, opts.color))
    }
  }
}

///|
async fn cmd_ready(opts : GlobalOptions) -> Unit {
  let store = @tracker.Store::new()
  let issues = store.load_issues()
  if issues.length() == 0 {
    if !opts.json {
      @stdio.stdout.write("no issues\n")
    }
    return
  }
  let status_map = @tracker.build_status_map(issues)
  let ready = issues.filter(issue => @tracker.is_ready(issue, status_map))
  if ready.length() == 0 {
    if !opts.json {
      @stdio.stdout.write("no ready issues\n")
    }
    return
  }
  if opts.json {
    for issue in ready {
      write_issue_json(issue)
    }
  } else {
    for issue in ready {
      @stdio.stdout.write(format_issue_line(issue, opts.color))
    }
  }
}

///|
async fn cmd_show(opts : GlobalOptions, id : String) -> Unit {
  let store = @tracker.Store::new()
  let issues = store.load_issues()
  match @tracker.find_issue_index(issues, id) {
    Some(index) => {
      let issue = issues[index]
      if opts.json {
        write_issue_json(issue)
        return
      }
      @stdio.stdout.write("id: \{format_id(issue.id, opts.color)}\n")
      @stdio.stdout.write("title: \{issue.title}\n")
      @stdio.stdout.write(
        "status: \{format_status(issue.status, opts.color)}\n",
      )
      @stdio.stdout.write(
        "priority: \{format_priority_value(issue.priority, opts.color)}\n",
      )
      @stdio.stdout.write("created_at: \{issue.created_at.to_string()}\n")
      @stdio.stdout.write("updated_at: \{issue.updated_at.to_string()}\n")
      let deps = if issue.deps.length() == 0 {
        "-"
      } else {
        issue.deps.join(", ")
      }
      @stdio.stdout.write("deps: \{deps}\n")
      if !issue.notes.trim().is_empty() {
        @stdio.stdout.write("notes: \{issue.notes}\n")
      }
    }
    None => @stdio.stderr.write("error: issue not found\n")
  }
}

///|
async fn cmd_set_status(
  opts : GlobalOptions,
  id : String,
  status_input : String,
) -> Unit {
  let status = match @tracker.normalize_status(status_input) {
    Some(value) => value
    None => {
      @stdio.stderr.write("error: invalid status\n")
      return
    }
  }
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      match @tracker.find_issue_index(issues, id) {
        Some(index) => {
          let issue = issues[index]
          let now = @env.now()
          let updated = @tracker.Issue::{
            id: issue.id,
            title: issue.title,
            status,
            priority: issue.priority,
            created_at: issue.created_at,
            updated_at: now,
            deps: issue.deps,
            notes: issue.notes,
          }
          issues[index] = updated
          store.save_issues(issues)
          Ok(updated)
        }
        None => Err("issue not found")
      }
    },
    force=opts.force,
  )
  match result {
    Some(Ok(issue)) =>
      if opts.json {
        write_issue_json(issue)
      } else {
        @stdio.stdout.write("updated \{id} -> \{status}\n")
      }
    Some(Err(msg)) => @stdio.stderr.write("error: \{msg}\n")
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_update(
  opts : GlobalOptions,
  id : String,
  args : ArrayView[String],
) -> Unit {
  let update_opts = match parse_update_args(args) {
    Ok(opts) => opts
    Err(msg) => {
      @stdio.stderr.write("error: \{msg}\n")
      return
    }
  }
  if update_opts.title is None &&
    update_opts.notes is None &&
    update_opts.append_notes is None &&
    update_opts.priority is None {
    @stdio.stderr.write("error: no fields to update\n")
    return
  }
  if update_opts.notes is Some(_) && update_opts.append_notes is Some(_) {
    @stdio.stderr.write("error: use --notes or --append-notes, not both\n")
    return
  }
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      match @tracker.find_issue_index(issues, id) {
        Some(index) => {
          let issue = issues[index]
          let now = @env.now()
          let title = match update_opts.title {
            Some(value) => value
            None => issue.title
          }
          let notes = match update_opts.notes {
            Some(value) => value
            None =>
              match update_opts.append_notes {
                Some(value) => {
                  let trimmed = value.trim()
                  if trimmed.is_empty() {
                    issue.notes
                  } else if issue.notes.trim().is_empty() {
                    value
                  } else {
                    issue.notes + "\n" + value
                  }
                }
                None => issue.notes
              }
          }
          let priority = match update_opts.priority {
            Some(value) => value
            None => issue.priority
          }
          let updated = @tracker.Issue::{
            id: issue.id,
            title,
            status: issue.status,
            priority,
            created_at: issue.created_at,
            updated_at: now,
            deps: issue.deps,
            notes,
          }
          issues[index] = updated
          store.save_issues(issues)
          Ok(updated)
        }
        None => Err("issue not found")
      }
    },
    force=opts.force,
  )
  match result {
    Some(Ok(issue)) =>
      if opts.json {
        write_issue_json(issue)
      } else {
        @stdio.stdout.write("updated \{id}\n")
      }
    Some(Err(msg)) => @stdio.stderr.write("error: \{msg}\n")
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_delete(opts : GlobalOptions, id : String) -> Unit {
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      match @tracker.find_issue_index(issues, id) {
        Some(index) => {
          ignore(issues.remove(index))
          let now = @env.now()
          for i, issue in issues {
            if issue.deps.any(dep => dep == id) {
              let deps = @tracker.remove_dep_value(issue.deps, id)
              let updated = @tracker.Issue::{
                id: issue.id,
                title: issue.title,
                status: issue.status,
                priority: issue.priority,
                created_at: issue.created_at,
                updated_at: now,
                deps,
                notes: issue.notes,
              }
              issues[i] = updated
            }
          }
          store.save_issues(issues)
          Ok(())
        }
        None => Err("issue not found")
      }
    },
    force=opts.force,
  )
  match result {
    Some(Ok(_)) =>
      if opts.json {
        write_json_action("delete", id~)
      } else {
        @stdio.stdout.write("deleted \{id}\n")
      }
    Some(Err(msg)) => @stdio.stderr.write("error: \{msg}\n")
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_dep_add(
  opts : GlobalOptions,
  child : String,
  parent : String,
) -> Unit {
  if child == parent {
    @stdio.stderr.write("error: dependency cannot be self\n")
    return
  }
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      let child_index = @tracker.find_issue_index(issues, child)
      let parent_index = @tracker.find_issue_index(issues, parent)
      guard child_index is Some(child_index) else {
        return Err("child issue not found")
      }
      guard parent_index is Some(_) else {
        return Err("parent issue not found")
      }
      if @tracker.would_create_cycle(issues, child, parent) {
        return Err("dependency would create cycle")
      }
      let issue = issues[child_index]
      if issue.deps.any(dep => dep == parent) {
        return Err("dependency already present")
      }
      let deps = issue.deps.copy()
      deps.push(parent)
      let now = @env.now()
      let updated = @tracker.Issue::{
        id: issue.id,
        title: issue.title,
        status: issue.status,
        priority: issue.priority,
        created_at: issue.created_at,
        updated_at: now,
        deps,
        notes: issue.notes,
      }
      issues[child_index] = updated
      store.save_issues(issues)
      Ok(updated)
    },
    force=opts.force,
  )
  match result {
    Some(Ok(issue)) =>
      if opts.json {
        write_issue_json(issue)
      } else {
        @stdio.stdout.write("added dependency \{child} -> \{parent}\n")
      }
    Some(Err(msg)) => @stdio.stderr.write("error: \{msg}\n")
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn cmd_dep_remove(
  opts : GlobalOptions,
  child : String,
  parent : String,
) -> Unit {
  if child == parent {
    @stdio.stderr.write("error: dependency cannot be self\n")
    return
  }
  let store = @tracker.Store::new()
  store.ensure_workspace()
  let result = @tracker.with_lock(
    store.lock_path(),
    fn() {
      let issues = store.load_issues()
      let child_index = @tracker.find_issue_index(issues, child)
      guard child_index is Some(child_index) else {
        return Err("child issue not found")
      }
      let issue = issues[child_index]
      if !issue.deps.any(dep => dep == parent) {
        return Err("dependency not present")
      }
      let deps = @tracker.remove_dep_value(issue.deps, parent)
      let now = @env.now()
      let updated = @tracker.Issue::{
        id: issue.id,
        title: issue.title,
        status: issue.status,
        priority: issue.priority,
        created_at: issue.created_at,
        updated_at: now,
        deps,
        notes: issue.notes,
      }
      issues[child_index] = updated
      store.save_issues(issues)
      Ok(updated)
    },
    force=opts.force,
  )
  match result {
    Some(Ok(issue)) =>
      if opts.json {
        write_issue_json(issue)
      } else {
        @stdio.stdout.write("removed dependency \{child} -> \{parent}\n")
      }
    Some(Err(msg)) => @stdio.stderr.write("error: \{msg}\n")
    None => @stdio.stderr.write("error: workspace locked\n")
  }
}

///|
async fn print_usage() -> Unit {
  @stdio.stdout.write("Usage:\n")
  @stdio.stdout.write("  moonbead <command> [flags]\n\n")
  @stdio.stdout.write("Available Commands:\n")
  @stdio.stdout.write("  init        Initialize .beads + AGENTS.md\n")
  @stdio.stdout.write("  onboard     Print AGENTS.md snippet\n")
  @stdio.stdout.write("  prime       Print agent workflow prompt\n")
  @stdio.stdout.write("  create <title...>   Create issue\n")
  @stdio.stdout.write("  list                List issues\n")
  @stdio.stdout.write("  ready               List ready issues\n")
  @stdio.stdout.write("  show <id>           Show issue details\n")
  @stdio.stdout.write("  update <id>         Update title/notes/priority\n")
  @stdio.stdout.write("  delete <id>         Delete issue\n")
  @stdio.stdout.write("  close <id>          Mark issue closed\n")
  @stdio.stdout.write("  status <id> <status>  Set status\n")
  @stdio.stdout.write("  dep add <child> <parent>   Add dependency\n")
  @stdio.stdout.write("  dep remove <child> <parent>  Remove dependency\n\n")
  @stdio.stdout.write("Flags:\n")
  @stdio.stdout.write("  -h, --help             Show help\n")
  @stdio.stdout.write(
    "  --json                 Output JSON (list/ready as JSONL)\n",
  )
  @stdio.stdout.write("  --force                Remove existing lock\n")
  @stdio.stdout.write("  --no-color             Disable ANSI colors\n")
  @stdio.stdout.write("  -p, --priority <n>      Create/list/update\n")
  @stdio.stdout.write("  --notes <text>          Create/update\n")
  @stdio.stdout.write("  --append-notes <text>   Update (append)\n")
  @stdio.stdout.write("  --title <text>          Update\n")
  @stdio.stdout.write("  --status <status>       List\n")
  @stdio.stdout.write("  --all                   List (include closed)\n")
  @stdio.stdout.write("  --ready                 List (ready only)\n")
  @stdio.stdout.write("  --search <text>         List (title/notes)\n")
  @stdio.stdout.write("  --sort priority         List\n")
}

///|
fn format_issue_line(issue : @tracker.Issue, color : Bool) -> String {
  let id = format_id(issue.id, color)
  let status = format_status(issue.status, color)
  let priority = format_priority_label(issue.priority, color)
  "\{id} [\{status}] \{priority} \{issue.title}\n"
}

///|
let ansi_reset = "\u001b[0m"

///|
let ansi_red = "\u001b[31m"

///|
let ansi_green = "\u001b[32m"

///|
let ansi_yellow = "\u001b[33m"

///|
let ansi_cyan = "\u001b[36m"

///|
let ansi_gray = "\u001b[90m"

///|
fn colorize(value : String, color : String, enabled : Bool) -> String {
  if enabled {
    color + value + ansi_reset
  } else {
    value
  }
}

///|
fn status_color(status : String) -> String {
  if status == @tracker.status_open {
    ansi_green
  } else if status == @tracker.status_in_progress {
    ansi_yellow
  } else if status == @tracker.status_blocked {
    ansi_red
  } else if status == @tracker.status_closed {
    ansi_gray
  } else {
    ansi_cyan
  }
}

///|
fn format_status(status : String, enabled : Bool) -> String {
  colorize(status, status_color(status), enabled)
}

///|
fn priority_color(priority : Int) -> String {
  if priority <= 1 {
    ansi_red
  } else if priority == 2 {
    ansi_yellow
  } else if priority == 3 {
    ansi_green
  } else {
    ansi_cyan
  }
}

///|
fn format_priority_label(priority : Int, enabled : Bool) -> String {
  let label = "p\{priority}"
  colorize(label, priority_color(priority), enabled)
}

///|
fn format_priority_value(priority : Int, enabled : Bool) -> String {
  let value = "\{priority}"
  colorize(value, priority_color(priority), enabled)
}

///|
fn format_id(id : String, enabled : Bool) -> String {
  colorize(id, ansi_cyan, enabled)
}

///|
async fn write_issue_json(issue : @tracker.Issue) -> Unit {
  @stdio.stdout.write("\{issue.to_json().stringify()}\n")
}

///|
async fn write_json_action(
  action : String,
  id? : String = "",
  path? : String = "",
) -> Unit {
  let payload = ActionPayload::{
    action,
    id: if id.is_empty() {
      None
    } else {
      Some(id)
    },
    path: if path.is_empty() {
      None
    } else {
      Some(path)
    },
  }
  @stdio.stdout.write("\{payload.to_json().stringify()}\n")
}

///|
fn parse_global_options(args : Array[String]) -> (GlobalOptions, Array[String]) {
  let mut json = false
  let mut force = false
  let mut color = true
  let rest : Array[String] = []
  for i, arg in args {
    if i == 0 {
      rest.push(arg)
      continue
    }
    match arg {
      "--json" => json = true
      "--force" => force = true
      "--no-color" => color = false
      _ => rest.push(arg)
    }
  }
  (GlobalOptions::{ json, force, color }, rest)
}

///|
fn parse_list_args(args : ArrayView[String]) -> Result[ListOptions, String] {
  let mut status : String? = None
  let mut priority : Int? = None
  let mut ready_only = false
  let mut search : String? = None
  let mut sort_priority = false
  let mut all = false
  for i = 0; i < args.length(); {
    let arg = args[i]
    match arg {
      "--status" => {
        if i + 1 >= args.length() {
          return Err("missing value for --status")
        }
        let raw = args[i + 1]
        match @tracker.normalize_status(raw) {
          Some(value) => status = Some(value)
          None => return Err("invalid status")
        }
        continue i + 2
      }
      "--priority" | "-p" => {
        if i + 1 >= args.length() {
          return Err("missing value for --priority")
        }
        match parse_priority(args[i + 1]) {
          Some(value) => priority = Some(value)
          None => return Err("invalid priority")
        }
        continue i + 2
      }
      "--ready" => {
        ready_only = true
        continue i + 1
      }
      "--all" => {
        all = true
        continue i + 1
      }
      "--search" => {
        if i + 1 >= args.length() {
          return Err("missing value for --search")
        }
        search = Some(args[i + 1])
        continue i + 2
      }
      "--sort" => {
        if i + 1 >= args.length() {
          return Err("missing value for --sort")
        }
        match args[i + 1] {
          "priority" => sort_priority = true
          _ => return Err("unknown sort")
        }
        continue i + 2
      }
      _ => return Err("unknown option \{arg}")
    }
  } else {
    Ok(ListOptions::{ status, priority, ready_only, search, sort_priority, all })
  }
}

///|
fn parse_create_args(args : ArrayView[String]) -> Result[CreateOptions, String] {
  let mut priority = 2
  let mut notes = ""
  let title_parts : Array[String] = []
  for i = 0; i < args.length(); {
    let arg = args[i]
    match arg {
      "--priority" | "-p" => {
        if i + 1 >= args.length() {
          return Err("missing value for --priority")
        }
        match parse_priority(args[i + 1]) {
          Some(value) => priority = value
          None => return Err("invalid priority")
        }
        continue i + 2
      }
      "--notes" => {
        if i + 1 >= args.length() {
          return Err("missing value for --notes")
        }
        notes = args[i + 1]
        continue i + 2
      }
      "--" =>
        for j = i + 1; j < args.length(); {
          title_parts.push(args[j])
          continue j + 1
        } else {
          continue args.length()
        }
      _ => {
        title_parts.push(arg)
        continue i + 1
      }
    }
  } else {
    let title = title_parts.join(" ")
    if title.trim().is_empty() {
      return Err("title required")
    }
    Ok(CreateOptions::{ title, priority, notes })
  }
}

///|
fn parse_update_args(args : ArrayView[String]) -> Result[UpdateOptions, String] {
  let mut title : String? = None
  let mut notes : String? = None
  let mut append_notes : String? = None
  let mut priority : Int? = None
  for i = 0; i < args.length(); {
    let arg = args[i]
    match arg {
      "--title" => {
        if i + 1 >= args.length() {
          return Err("missing value for --title")
        }
        title = Some(args[i + 1])
        continue i + 2
      }
      "--notes" => {
        if i + 1 >= args.length() {
          return Err("missing value for --notes")
        }
        notes = Some(args[i + 1])
        continue i + 2
      }
      "--append-notes" => {
        if i + 1 >= args.length() {
          return Err("missing value for --append-notes")
        }
        append_notes = Some(args[i + 1])
        continue i + 2
      }
      "--priority" | "-p" => {
        if i + 1 >= args.length() {
          return Err("missing value for --priority")
        }
        match parse_priority(args[i + 1]) {
          Some(value) => priority = Some(value)
          None => return Err("invalid priority")
        }
        continue i + 2
      }
      _ => return Err("unknown option \{arg}")
    }
  } else {
    Ok(UpdateOptions::{ title, notes, append_notes, priority })
  }
}

///|
fn parse_priority(value : String) -> Int? {
  try @strconv.parse_int(value, base=10) catch {
    _ => None
  } noraise {
    num => Some(num)
  }
}

///|
fn compare_priority_then_id(a : @tracker.Issue, b : @tracker.Issue) -> Int {
  if a.priority < b.priority {
    -1
  } else if a.priority > b.priority {
    1
  } else if a.id < b.id {
    -1
  } else if a.id > b.id {
    1
  } else {
    0
  }
}
