import glox/token.{Token}
import gleam/string_builder
import gleam/list
import gleam/float
import gleam/bool
import gleam/result
import gleam/io

pub type Expression {
  Binary(left: Expression, operator: Token, right: Expression)
  Grouping(expression: Expression)
  Unary(operator: Token, expression: Expression)
  LiteralBool(value: Bool)
  LiteralNil
  LiteralNumber(value: Float)
  LiteralString(value: String)
}

pub type Statement {
  Expression(expression: Expression)
  Print(expression: Expression)
}

/// Turns an expression into a (not very) pretty string.
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
  DivisionByZero
}

pub type LoxValue {
  LoxBool(value: Bool)
  LoxNumber(value: Float)
  LoxNil
  LoxString(value: String)
}

fn lox_value_to_string(value: LoxValue) {
  case value {
    LoxBool(bool) -> bool.to_string(bool)
    LoxNumber(float) -> float.to_string(float)
    LoxNil -> "nil"
    LoxString(string) -> string
  }
}

pub fn eval(program: List(Statement)) -> Result(Nil, EvalError) {
  program
  |> list.try_each(eval_statement)
}

fn eval_statement(statement: Statement) -> Result(Nil, EvalError) {
  case statement {
    Print(expression) ->
      eval_expression(expression)
      |> result.map(fn(e) { io.println(lox_value_to_string(e)) })
      |> result.replace(Nil)
    Expression(expression) ->
      eval_expression(expression)
      |> result.replace(Nil)
  }
}

fn eval_expression(expression: Expression) -> Result(LoxValue, EvalError) {
  case expression {
    LiteralBool(value) -> Ok(LoxBool(value))
    LiteralNumber(value) -> Ok(LoxNumber(value))
    LiteralString(value) -> Ok(LoxString(value))
    LiteralNil -> Ok(LoxNil)
    Grouping(expression) -> eval_expression(expression)
    Unary(token, expression) -> eval_unary(token, expression)
    Binary(left, token, right) -> eval_binary(left, token, right)
  }
}

fn eval_unary(
  token: Token,
  expression: Expression,
) -> Result(LoxValue, EvalError) {
  use value <- result.then(eval_expression(expression))
  case token.token_type {
    token.Bang -> Ok(LoxBool(!is_truthy(value)))
    token.Minus ->
      case value {
        LoxNumber(number) -> Ok(LoxNumber(float.negate(number)))
        _ -> Error(WrongType(expected: "number", got: value))
      }
    _ -> panic
  }
}

fn is_truthy(result: LoxValue) -> Bool {
  case result {
    LoxBool(False) | LoxNil -> False
    _ -> True
  }
}

fn eval_binary(
  left_expression: Expression,
  token: Token,
  right_expression: Expression,
) -> Result(LoxValue, EvalError) {
  use left <- result.then(eval_expression(left_expression))
  use right <- result.then(eval_expression(right_expression))

  case token.token_type {
    token.Plus -> binary_plus(left, right)
    token.Minus -> float_to_float(left, right, float.subtract)
    token.Star -> float_to_float(left, right, float.multiply)
    token.Slash -> float_to_result(left, right, lox_divide)
    token.Greater -> float_to_bool(left, right, fn(n, m) { n >. m })
    token.GreaterEqual -> float_to_bool(left, right, fn(n, m) { n >=. m })
    token.Less -> float_to_bool(left, right, fn(n, m) { n <. m })
    token.LessEqual -> float_to_bool(left, right, fn(n, m) { n <=. m })
    token.EqualEqual -> Ok(LoxBool(left == right))
    token.BangEqual -> Ok(LoxBool(left != right))
    _ -> panic
  }
}

fn binary_plus(left: LoxValue, right: LoxValue) -> Result(LoxValue, EvalError) {
  case left, right {
    LoxNumber(n), LoxNumber(m) -> Ok(LoxNumber(n +. m))
    LoxNumber(_), _ -> Error(WrongType(expected: "number", got: right))
    _, LoxNumber(_) -> Error(WrongType(expected: "number", got: left))
    LoxString(s1), LoxString(s2) -> Ok(LoxString(s1 <> s2))
    LoxString(_), _ -> Error(WrongType(expected: "string", got: right))
    _, LoxString(_) -> Error(WrongType(expected: "string", got: left))
    _, _ -> Error(WrongType(expected: "number or string", got: left))
  }
}

fn float_to_float(
  left: LoxValue,
  right: LoxValue,
  op: fn(Float, Float) -> Float,
) -> Result(LoxValue, EvalError) {
  float_to_result(left, right, fn(n, m) { Ok(LoxNumber(op(n, m))) })
}

fn float_to_bool(
  left: LoxValue,
  right: LoxValue,
  op: fn(Float, Float) -> Bool,
) -> Result(LoxValue, EvalError) {
  float_to_result(left, right, fn(n, m) { Ok(LoxBool(op(n, m))) })
}

fn float_to_result(
  left: LoxValue,
  right: LoxValue,
  op: fn(Float, Float) -> Result(LoxValue, EvalError),
) {
  case left, right {
    LoxNumber(n), LoxNumber(m) -> op(n, m)
    LoxNumber(_), _ -> Error(WrongType(expected: "number", got: right))
    _, LoxNumber(_) -> Error(WrongType(expected: "number", got: left))
    _, _ -> Error(WrongType(expected: "number", got: left))
  }
}

fn lox_divide(n: Float, m: Float) -> Result(LoxValue, EvalError) {
  case m {
    0.0 -> Error(DivisionByZero)
    _ -> Ok(LoxNumber(n /. m))
  }
}
