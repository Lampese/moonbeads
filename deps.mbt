///|
pub fn would_create_cycle(
  issues : Array[Issue],
  child : String,
  parent : String,
) -> Bool {
  if child == parent {
    return true
  }
  let graph = build_dep_map(issues)
  has_path(graph, parent, child, {})
}

///|
pub fn remove_dep_value(deps : Array[String], target : String) -> Array[String] {
  deps.filter(dep => dep != target)
}

///|
fn build_dep_map(issues : Array[Issue]) -> Map[String, Array[String]] {
  let map : Map[String, Array[String]] = {}
  for issue in issues {
    map[issue.id] = issue.deps
  }
  map
}

///|
fn has_path(
  graph : Map[String, Array[String]],
  current : String,
  target : String,
  visited : Map[String, Bool],
) -> Bool {
  if current == target {
    return true
  }
  match visited.get(current) {
    Some(true) => return false
    _ => ()
  }
  visited[current] = true
  match graph.get(current) {
    Some(deps) =>
      for dep in deps {
        if has_path(graph, dep, target, visited) {
          return true
        }
      }
    None => ()
  }
  false
}
