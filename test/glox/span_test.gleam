import glacier/should
import glox/span.{Span}

pub fn merge_test() {
  Span(line_start: 1, line_end: 3, column_start: 1, column_end: 10)
  |> span.merge(Span(line_start: 2, line_end: 4, column_start: 3, column_end: 5))
  |> should.equal(Span(
    line_start: 1,
    line_end: 4,
    column_start: 1,
    column_end: 10,
  ))
}
