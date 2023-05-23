import glox/token.{Token}
import gleam/string_builder
import gleam/list
import gleam/float
import gleam/bool

pub type Expression {
  Binary(left: Expression, operator: Token, right: Expression)
  Grouping(expression: Expression)
  Unary(operator: Token, expression: Expression)
  LiteralBool(value: Bool)
  LiteralNil
  LiteralNumber(value: Float)
  LiteralString(value: String)
}

/// Turns an expression into a (not very) pretty string that can be displayed.
pub fn to_string(expression: Expression) -> String {
  case expression {
    Binary(left, operator, right) ->
      parenthesize(token.lexeme(operator), [left, right])
    Grouping(expression) -> parenthesize("group", [expression])
    LiteralBool(value) -> bool.to_string(value)
    LiteralNumber(value) -> float.to_string(value)
    LiteralNil -> "nil"
    LiteralString(value) -> "\"" <> value <> "\""
    Unary(operator, expression) ->
      parenthesize(token.lexeme(operator), [expression])
  }
}

fn parenthesize(name: String, expressions: List(Expression)) -> String {
  string_builder.new()
  |> string_builder.append("(")
  |> string_builder.append(name)
  |> string_builder.append(" ")
  |> string_builder.append_builder(
    expressions
    |> list.map(to_string)
    |> list.intersperse(" ")
    |> string_builder.from_strings,
  )
  |> string_builder.append(")")
  |> string_builder.to_string
}
