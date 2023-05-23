import glacier/should
import glox/scanner.{ScannerError}
import glox/token.{Token}
import gleam/pair
import gleam/list
import glox/span.{Span}

fn map_2(over list: List(#(a, b)), with fun: fn(a, b) -> c) -> List(c) {
  list
  |> list.map(fn(pair) { fun(pair.0, pair.1) })
}

fn map_3(over list: List(#(a, b, c)), with fun: fn(a, b, c) -> d) -> List(d) {
  list
  |> list.map(fn(triple) { fun(triple.0, triple.1, triple.2) })
}

fn scan_first(source: String) -> Result(Token, ScannerError) {
  source
  |> scanner.new
  |> scanner.next
  |> pair.second
}

pub fn ignores_newline_test() {
  "\n"
  |> scan_first
  |> should.be_ok
  |> should.equal(token.eof(2, 1))

  "\r\n"
  |> scan_first
  |> should.be_ok
  |> should.equal(token.eof(2, 1))
}

pub fn ignores_whitespace_test() {
  "  \t  "
  |> scan_first
  |> should.be_ok
  |> should.equal(token.eof(1, 6))
}

pub fn ignores_comment_test() {
  "// Yay a comment!\n"
  |> scan_first
  |> should.be_ok
  |> should.equal(token.eof(2, 1))

  "// Yay a comment!"
  |> scan_first
  |> should.be_ok
  |> should.equal(token.eof(1, 18))
}

pub fn single_char_tokens_test() {
  [
    #("(", token.LeftParen),
    #(")", token.RightParen),
    #("{", token.LeftBrace),
    #("}", token.RightBrace),
    #("}", token.RightBrace),
    #(",", token.Comma),
    #(";", token.Semicolon),
    #(".", token.Dot),
    #("!", token.Bang),
    #("+", token.Plus),
    #("-", token.Minus),
    #("*", token.Star),
    #("/", token.Slash),
    #("=", token.Equal),
    #(">", token.Greater),
    #("<", token.Less),
  ]
  |> map_2(fn(source, expected_type) {
    source
    |> scan_first
    |> should.be_ok
    |> should.equal(Token(
      token_type: expected_type,
      span: span.single_line(on: 1, starts_at: 1, ends_at: 1),
    ))
  })
}

pub fn double_char_tokens_test() {
  [
    #(">=", token.GreaterEqual),
    #("<=", token.LessEqual),
    #("==", token.EqualEqual),
    #("!=", token.BangEqual),
  ]
  |> map_2(fn(source, expected_type) {
    source
    |> scan_first
    |> should.be_ok
    |> should.equal(Token(
      token_type: expected_type,
      span: span.single_line(on: 1, starts_at: 1, ends_at: 2),
    ))
  })
}

pub fn number_test() {
  "1"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Number("1"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 1),
  ))

  "123"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Number("123"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 3),
  ))

  "123."
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Number("123."),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 4),
  ))

  "123.123"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Number("123.123"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 7),
  ))

  "9876543210.0123456789"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Number("9876543210.0123456789"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 21),
  ))

  "123 12.2\n11.1"
  |> scanner.new
  |> scanner.scan
  |> should.be_ok
  |> should.equal([
    Token(
      token_type: token.Number("123"),
      span: span.single_line(on: 1, starts_at: 1, ends_at: 3),
    ),
    Token(
      token_type: token.Number("12.2"),
      span: span.single_line(on: 1, starts_at: 5, ends_at: 8),
    ),
    Token(
      token_type: token.Number("11.1"),
      span: span.single_line(on: 2, starts_at: 1, ends_at: 4),
    ),
  ])

  "-11"
  |> scanner.new
  |> scanner.scan
  |> should.be_ok
  |> should.equal([
    token.minus(1, 1),
    Token(
      token_type: token.Number("11"),
      span: span.single_line(on: 1, starts_at: 2, ends_at: 3),
    ),
  ])
}

pub fn string_test() {
  "\"\""
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.String(""),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 2),
  ))

  "\"Hello, world!\""
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.String("Hello, world!"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 15),
  ))

  "\"A multiline\nstring!\""
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.String("A multiline\nstring!"),
    span: Span(line_start: 1, line_end: 2, column_start: 1, column_end: 8),
  ))

  "\"\ntest\""
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.String("\ntest"),
    span: Span(line_start: 1, line_end: 2, column_start: 1, column_end: 5),
  ))

  " \"test\nmultiline\" 123 \"test\"11"
  |> scanner.new
  |> scanner.scan
  |> should.be_ok
  |> should.equal([
    Token(
      token_type: token.String("test\nmultiline"),
      span: Span(line_start: 1, line_end: 2, column_start: 2, column_end: 10),
    ),
    Token(
      token_type: token.Number("123"),
      span: Span(line_start: 2, line_end: 2, column_start: 12, column_end: 14),
    ),
    Token(
      token_type: token.String("test"),
      span: Span(line_start: 2, line_end: 2, column_start: 16, column_end: 21),
    ),
    Token(
      token_type: token.Number("11"),
      span: Span(line_start: 2, line_end: 2, column_start: 22, column_end: 23),
    ),
  ])
}

pub fn keywords_test() {
  [
    #("and", token.And, 3),
    #("class", token.Class, 5),
    #("else", token.Else, 4),
    #("false", token.False, 5),
    #("fun", token.Fun, 3),
    #("for", token.For, 3),
    #("if", token.If, 2),
    #("nil", token.Nil, 3),
    #("or", token.Or, 2),
    #("print", token.Print, 5),
    #("return", token.Return, 6),
    #("super", token.Super, 5),
    #("this", token.This, 4),
    #("true", token.True, 4),
    #("var", token.Var, 3),
    #("while", token.While, 5),
  ]
  |> map_3(fn(source, expected_type, length) {
    source
    |> scan_first
    |> should.be_ok
    |> should.equal(Token(
      token_type: expected_type,
      span: span.single_line(on: 1, starts_at: 1, ends_at: length),
    ))
  })

  "if.and or else"
  |> scanner.new
  |> scanner.scan
  |> should.be_ok
  |> should.equal([
    token.if_(1, 1),
    token.dot(1, 3),
    token.and(1, 4),
    token.or(1, 8),
    token.else(1, 11),
  ])
}

pub fn identifiers_test() {
  "foo"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("foo"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 3),
  ))

  "foo_bar"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("foo_bar"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 7),
  ))

  "foo123"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("foo123"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 6),
  ))

  "_foo"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("_foo"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 4),
  ))

  "_123"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("_123"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 4),
  ))

  "foo_123"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("foo_123"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 7),
  ))

  "andif"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("andif"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 5),
  ))

  "and_if"
  |> scan_first
  |> should.be_ok
  |> should.equal(Token(
    token_type: token.Identifier("and_if"),
    span: span.single_line(on: 1, starts_at: 1, ends_at: 6),
  ))

  "foo bar baz"
  |> scanner.new
  |> scanner.scan
  |> should.be_ok
  |> should.equal([
    Token(
      token_type: token.Identifier("foo"),
      span: span.single_line(on: 1, starts_at: 1, ends_at: 3),
    ),
    Token(
      token_type: token.Identifier("bar"),
      span: span.single_line(on: 1, starts_at: 5, ends_at: 7),
    ),
    Token(
      token_type: token.Identifier("baz"),
      span: span.single_line(on: 1, starts_at: 9, ends_at: 11),
    ),
  ])
}

pub fn error_case_test() {
  todo("add test for scanner errors!")
}
