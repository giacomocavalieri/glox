import gleam/iterator.{Done, Iterator, Next}

pub fn next_item(
  from iterator: Iterator(a),
  or return: b,
  with fun: fn(a, Iterator(a)) -> b,
) -> b {
  case iterator.step(iterator) {
    Done -> return
    Next(a, rest) -> fun(a, rest)
  }
}
