///|
pub fn join_path(base : StringView, child : StringView) -> String {
  if base.has_suffix("/") {
    "\{base}\{child}"
  } else {
    "\{base}/\{child}"
  }
}
