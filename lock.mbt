///|
pub struct Lock {
  path : String
}

///|
let lock_ttl_ms : Int64 = 10L * 60L * 1000L

///|
pub async fn acquire_lock(path : String, force? : Bool = false) -> Lock? {
  try @fs.mkdir(path, permission=0o700) catch {
    @os_error.OSError(_) as err if err.is_EEXIST() => {
      if force || lock_is_stale(path) {
        try @fs.rmdir(path, recursive=true) catch {
          _ => return None
        } noraise {
          _ => ()
        }
        return acquire_lock(path, force~)
      }
      return None
    }
    err => raise err
  } noraise {
    _ => ()
  }
  Some({ path, })
}

///|
pub async fn Lock::release(self : Lock) -> Unit {
  try @fs.rmdir(self.path, recursive=true) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
pub async fn[T] with_lock(
  path : String,
  op : async () -> T,
  force? : Bool = false,
) -> T? {
  let lock = acquire_lock(path, force~)
  guard lock is Some(lock) else { return None }
  try op() catch {
    err => {
      lock.release()
      raise err
    }
  } noraise {
    result => {
      lock.release()
      Some(result)
    }
  }
}

///|
async fn lock_is_stale(path : String) -> Bool {
  let (sec, ns) = @fs.mtime(path)
  let ms = sec * 1000L + Int64::from_int(ns / 1_000_000)
  let now_ms = @env.now().reinterpret_as_int64()
  let age = now_ms - ms
  age > lock_ttl_ms
}
