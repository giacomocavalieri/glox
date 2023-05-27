pub fn from_list_pair(result: #(List(a), List(e))) -> Result(List(a), List(e)) {
  case result.1 {
    [] -> Ok(result.0)
    _ -> Error(result.1)
  }
}

pub fn map_unwrap(
  result: Result(a, e),
  on_ok ok_map: fn(a) -> b,
  on_error error_map: fn(e) -> b,
) -> b {
  case result {
    Ok(a) -> ok_map(a)
    Error(e) -> error_map(e)
  }
}
