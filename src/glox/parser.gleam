import glox/expression.{Expression}
import glox/token.{Token, TokenType}
import gleam/iterator.{Iterator}
import gleam/list
import glox/internal/float_extra
import gleam/result
import glox/internal/result_extra
import glox/internal/iterator_extra

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
  #(Result(Expression, ParserError), Iterator(Token))

pub fn parse(tokens: Iterator(Token)) -> ParseResult {
  expression(tokens)
}

// expression -> equality
fn expression(tokens: Iterator(Token)) -> ParseResult {
  equality(tokens)
}

// equality -> comparison ( ( "==" | "!=" ) comparison )*
fn equality(tokens: Iterator(Token)) -> ParseResult {
  comparison(tokens)
  |> zero_or_more([token.EqualEqual, token.BangEqual], comparison)
}

// comparison -> term ( ( "<=" | "<" | ">" | ">=" ) term )*
fn comparison(tokens: Iterator(Token)) -> ParseResult {
  term(tokens)
  |> zero_or_more(
    [token.Greater, token.GreaterEqual, token.Less, token.LessEqual],
    term,
  )
}

// term -> factor ( ( "-" | "+" ) factor )*
fn term(tokens: Iterator(Token)) -> ParseResult {
  factor(tokens)
  |> zero_or_more([token.Minus, token.Plus], factor)
}

// factor -> unary ( ( "*" | "/" ) unary )*
fn factor(tokens: Iterator(Token)) -> ParseResult {
  unary(tokens)
  |> zero_or_more([token.Slash, token.Star], unary)
}

// unary -> ( "!" | "-" ) unary | primary
fn unary(tokens: Iterator(Token)) -> ParseResult {
  use token, rest <- expect_token(tokens, while: ExpectingUnaryOrPrimary)
  case token.token_type {
    token.Bang | token.Minus -> {
      let #(expression, rest) = unary(rest)
      #(result.map(expression, expression.Unary(token, _)), rest)
    }
    _ -> primary(tokens)
  }
}

// primary -> NUMBER | STRING | "true" | "false" | "nil" | "(" expression ")"
fn primary(tokens: Iterator(Token)) -> ParseResult {
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
  from start: ParseResult,
  allowed token_types: List(TokenType),
  using parser: fn(Iterator(Token)) -> ParseResult,
) -> ParseResult {
  let #(result, tokens) = start
  use left <- result_extra.map_unwrap(result, on_error: fn(_) { start })
  use token, rest <- iterator_extra.next_item(tokens, or: #(Ok(left), tokens))
  case list.contains(token_types, token.token_type) {
    False -> start
    True -> {
      let #(right, rest) = parser(rest)
      #(result.map(right, expression.Binary(left, token, _)), rest)
      |> zero_or_more(using: parser, allowed: token_types)
    }
  }
}

fn parse_number(literal: String) {
  let assert Ok(number) = float_extra.parse(literal)
  expression.LiteralNumber(number)
}

fn parse_group(starts_with: Token, tokens: Iterator(Token)) -> ParseResult {
  let #(expression, rest) = expression(tokens)
  use token, rest <- expect_token(from: rest, while: ParsingGroup(starts_with))
  case token.token_type {
    token.RightParen -> #(result.map(expression, expression.Grouping(_)), rest)
    _ -> #(Error(UnexpectedToken(token, ParsingGroup(starts_with))), rest)
  }
}

fn expect_token(
  from tokens: Iterator(Token),
  while context: ParserContext,
  with fun: fn(Token, Iterator(Token)) -> ParseResult,
) -> ParseResult {
  iterator_extra.next_item(
    from: tokens,
    or: #(Error(UnexpectedEof(context)), tokens),
    with: fun,
  )
}

fn synchronize(tokens: Iterator(Token)) -> Iterator(Token) {
  use token, rest <- iterator_extra.next_item(from: tokens, or: tokens)
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
