import glox/token.{Token}
import glox/span.{Span}
import gleam/string_builder
import gleam/list
import gleam/float
import gleam/bool
import gleam/result

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

pub type EvalError {
  // TODO: Add spans to AST nodes as well to keep data about location and report
  // it in the error message!
  WrongType(expected: String, got: LoxValue)
}

pub type LoxValue {
  LoxBool(value: Bool)
  LoxNumber(value: Float)
  LoxNil
  LoxString(value: String)
}

/// Evals an expression
pub fn eval(expression: Expression) -> Result(LoxValue, EvalError) {
  case expression {
    LiteralBool(value) -> Ok(LoxBool(value))
    LiteralNumber(value) -> Ok(LoxNumber(value))
    LiteralString(value) -> Ok(LoxString(value))
    LiteralNil -> Ok(LoxNil)
    Grouping(expression) -> eval(expression)
    Unary(token, expression) -> eval_unary(token, expression)
    Binary(left, token, right) -> eval_binary(left, token, right)
  }
}

fn eval_unary(
  token: Token,
  expression: Expression,
) -> Result(LoxValue, EvalError) {
  case token.token_type {
    token.Bang -> eval_bang(expression)
    token.Minus -> eval_minus(expression)
    _ ->
      string_builder.new()
      |> string_builder.append("eval unary: tried to eval \"")
      |> string_builder.append(token.lexeme(token))
      |> string_builder.append("\" as a unary operator.\n")
      |> string_builder.append("This should never happen ")
      |> string_builder.append("and is definitely a bug!")
      |> string_builder.to_string
      |> panic
  }
}

fn eval_bang(expression: Expression) -> Result(LoxValue, EvalError) {
  use value <- result.map(eval(expression))
  LoxBool(!is_truthy(value))
}

fn is_truthy(result: LoxValue) -> Bool {
  case result {
    LoxBool(False) | LoxNil -> False
    _ -> True
  }
}

fn eval_minus(expression: Expression) -> Result(LoxValue, EvalError) {
  use value <- result.then(eval(expression))
  case value {
    LoxNumber(number) -> Ok(LoxNumber(float.negate(number)))
    _ -> Error(WrongType(expected: "number", got: value))
  }
}

fn eval_binary(
  left: Expression,
  token: Token,
  right: Expression,
) -> Result(LoxValue, EvalError) {
  case token.token_type {
    token.Plus -> eval_binary_plus(left, right)
    token.Minus -> eval_binary_op(left, right, fn(n, m) { LoxNumber(n -. m) })
    token.Star -> eval_binary_op(left, right, fn(n, m) { LoxNumber(n *. m) })
    token.Slash -> eval_binary_op(left, right, fn(n, m) { LoxNumber(n /. m) })
    token.Greater -> eval_binary_op(left, right, fn(n, m) { LoxBool(n >. m) })
    token.GreaterEqual ->
      eval_binary_op(left, right, fn(n, m) { LoxBool(n >=. m) })
    token.Less -> eval_binary_op(left, right, fn(n, m) { LoxBool(n <. m) })
    token.LessEqual ->
      eval_binary_op(left, right, fn(n, m) { LoxBool(n <=. m) })
    token.EqualEqual -> eval_equal(left, right)
    token.BangEqual -> eval_bang_equal(left, right)
    _ ->
      string_builder.new()
      |> string_builder.append("eval binary: tried to eval \"")
      |> string_builder.append(token.lexeme(token))
      |> string_builder.append("\" as a binary operator.\n")
      |> string_builder.append("This should never happen ")
      |> string_builder.append("and is definitely a bug!")
      |> string_builder.to_string
      |> panic
  }
}

fn eval_binary_plus(left: Expression, right: Expression) {
  use left_value <- result.then(eval(left))
  use right_value <- result.then(eval(right))
  case left_value, right_value {
    LoxNumber(n), LoxNumber(m) -> Ok(LoxNumber(n +. m))
    LoxNumber(_), _ -> Error(WrongType(expected: "number", got: right_value))
    _, LoxNumber(_) -> Error(WrongType(expected: "number", got: left_value))
    LoxString(s1), LoxString(s2) -> Ok(LoxString(s1 <> s2))
    LoxString(_), _ -> Error(WrongType(expected: "string", got: right_value))
    _, LoxString(_) -> Error(WrongType(expected: "string", got: left_value))
    _, _ -> Error(WrongType(expected: "number or string", got: left_value))
  }
}

fn eval_binary_op(
  left: Expression,
  right: Expression,
  op: fn(Float, Float) -> LoxValue,
) -> Result(LoxValue, EvalError) {
  use left_value <- result.then(eval(left))
  use right_value <- result.then(eval(right))
  case left_value, right_value {
    LoxNumber(n), LoxNumber(m) -> Ok(op(n, m))
    LoxNumber(_), _ -> Error(WrongType(expected: "number", got: right_value))
    _, LoxNumber(_) -> Error(WrongType(expected: "number", got: left_value))
    _, _ -> Error(WrongType(expected: "number", got: left_value))
  }
}

fn eval_equal(
  left: Expression,
  right: Expression,
) -> Result(LoxValue, EvalError) {
  use left_value <- result.then(eval(left))
  use right_value <- result.map(eval(right))
  LoxBool(left_value == right_value)
}

fn eval_bang_equal(
  left: Expression,
  right: Expression,
) -> Result(LoxValue, EvalError) {
  use left_value <- result.then(eval(left))
  use right_value <- result.map(eval(right))
  LoxBool(left_value != right_value)
}
