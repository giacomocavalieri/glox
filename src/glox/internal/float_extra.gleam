import gleam/int
import gleam/result
import gleam/float

/// A parser that is a bit more permissive than the stdlib
/// parser, if it encounters a literal string for an int
/// it converts it to a Float.
/// All the floats it can parse:
/// - `0.5  // normal float`
/// - `12. // trailing dot floats`
/// - `12 // integer strings as floats`
pub fn parse(string: String) -> Result(Float, Nil) {
  int.parse(string)
  |> result.map(int.to_float)
  |> result.or(float.parse(string))
  |> result.or(float.parse(string <> "0"))
}
