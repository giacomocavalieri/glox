import gleam/int

pub type Span {
  Span(line_start: Int, line_end: Int, column_start: Int, column_end: Int)
}

pub fn single_line(
  on line: Int,
  starts_at column_start: Int,
  ends_at column_end: Int,
) -> Span {
  Span(
    line_start: line,
    line_end: line,
    column_start: column_start,
    column_end: column_end,
  )
}

pub fn merge(one: Span, other: Span) -> Span {
  Span(
    line_start: int.min(one.line_start, other.line_start),
    line_end: int.max(one.line_end, other.line_end),
    column_start: int.min(one.column_start, other.column_start),
    column_end: int.max(one.column_end, other.column_end),
  )
}
