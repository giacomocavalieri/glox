import glox/expression.{Expression, Statement}
import glox/token.{Token, TokenType}
import gleam/list
import glox/internal/float_extra
import gleam/result
import glox/internal/result_extra
import gleam/pair
import gleam/bool

pub type ParserContext {
  ParsingGroup(starts_at: Token)
  ExpectingPrimary
  ExpectingUnaryOrPrimary
  ExpectingExpression
}

pub type ParserError {
  UnexpectedEof(context: ParserContext)
  UnexpectedToken(token: Token, context: ParserContext)
}

pub type ParseResult =
  #(Result(Expression, ParserError), List(Token))

pub fn parse(tokens: List(Token)) -> List(Result(Statement, ParserError)) {
  do_parse(tokens, [])
}

pub fn do_parse(
  tokens: List(Token),
  acc: List(Result(Statement, ParserError)),
) -> List(Result(Statement, ParserError)) {
  case tokens {
    [] -> list.reverse(acc)
    _ -> {
      let #(result, rest) = statement(tokens)
      do_parse(rest, [result, ..acc])
    }
  }
}

fn statement(
  tokens: List(Token),
) -> #(Result(Statement, ParserError), List(Token)) {
  todo
}

// expression -> equality
fn expression(tokens: List(Token)) -> ParseResult {
  equality(tokens)
}

// equality -> comparison ( ( "==" | "!=" ) comparison )*
fn equality(tokens: List(Token)) -> ParseResult {
  comparison(tokens)
  |> zero_or_more([token.EqualEqual, token.BangEqual], comparison)
}

// comparison -> term ( ( "<=" | "<" | ">" | ">=" ) term )*
fn comparison(tokens: List(Token)) -> ParseResult {
  term(tokens)
  |> zero_or_more(
    [token.Greater, token.GreaterEqual, token.Less, token.LessEqual],
    term,
  )
}

// term -> factor ( ( "-" | "+" ) factor )*
fn term(tokens: List(Token)) -> ParseResult {
  factor(tokens)
  |> zero_or_more([token.Minus, token.Plus], factor)
}

// factor -> unary ( ( "*" | "/" ) unary )*
fn factor(tokens: List(Token)) -> ParseResult {
  unary(tokens)
  |> zero_or_more([token.Slash, token.Star], unary)
}

// unary -> ( "!" | "-" ) unary | primary
fn unary(tokens: List(Token)) -> ParseResult {
  case tokens {
    [] -> #(Error(UnexpectedEof(ExpectingUnaryOrPrimary)), [])
    [Token(token.Bang, ..) as token, ..rest]
    | [Token(token.Minus, ..) as token, ..rest] ->
      unary(rest)
      |> pair.map_first(result.map(_, expression.Unary(token, _)))
    _ -> primary(tokens)
  }
}

// primary -> NUMBER | STRING | "true" | "false" | "nil" | "(" expression ")"
fn primary(tokens: List(Token)) -> ParseResult {
  use token, rest <- expect_token(tokens, while: ExpectingPrimary)
  case token.token_type {
    token.Number(literal) -> #(Ok(parse_number(literal)), rest)
    token.String(literal) -> #(Ok(expression.LiteralString(literal)), rest)
    token.True -> #(Ok(expression.LiteralBool(True)), rest)
    token.False -> #(Ok(expression.LiteralBool(False)), rest)
    token.Nil -> #(Ok(expression.LiteralNil), rest)
    token.LeftParen -> parse_group(token, rest)
    _ -> #(Error(UnexpectedToken(token, ExpectingExpression)), rest)
  }
}

fn zero_or_more(
  from accumulator: ParseResult,
  allowed token_types: List(TokenType),
  using parser: fn(List(Token)) -> ParseResult,
) -> ParseResult {
  let #(result, tokens) = accumulator
  use left <- result_extra.map_unwrap(result, on_error: fn(_) { accumulator })
  case tokens {
    [] -> #(Ok(left), [])
    [token, ..rest] -> {
      case list.contains(token_types, token.token_type) {
        False -> accumulator
        True ->
          parser(rest)
          |> pair.map_first(result.map(_, expression.Binary(left, token, _)))
          |> zero_or_more(using: parser, allowed: token_types)
      }
    }
  }
}

fn parse_number(literal: String) {
  let assert Ok(number) = float_extra.parse(literal)
  expression.LiteralNumber(number)
}

fn parse_group(starts_with: Token, tokens: List(Token)) -> ParseResult {
  let #(expression, rest) = expression(tokens)
  use token, rest <- expect_token(from: rest, while: ParsingGroup(starts_with))
  case token.token_type {
    token.RightParen -> #(result.map(expression, expression.Grouping(_)), rest)
    _ -> #(Error(UnexpectedToken(token, ParsingGroup(starts_with))), rest)
  }
}

fn expect_token(
  from tokens: List(Token),
  while context: ParserContext,
  with fun: fn(Token, List(Token)) -> ParseResult,
) -> ParseResult {
  case tokens {
    [] -> #(Error(UnexpectedEof(context)), [])
    [token, ..rest] -> fun(token, rest)
  }
}

fn synchronize(tokens: List(Token)) -> List(Token) {
  case tokens {
    [] -> []
    [token, ..rest] ->
      case token.token_type {
        token.Semicolon -> rest
        token.Class
        | token.Fun
        | token.Var
        | token.For
        | token.If
        | token.While
        | token.Print
        | token.Return -> tokens
        _ -> synchronize(rest)
      }
  }
}
