import glox/token.{Token}
import gleam/string
import gleam/iterator.{Iterator}
import gleam/list
import gleam/string_builder.{StringBuilder}
import glox/span.{Span}
import glox/internal/string_extra

pub opaque type Scanner {
  Scanner(graphemes: List(String), line: Int, column: Int)
}

pub fn new(source: String) -> Scanner {
  Scanner(graphemes: string.to_graphemes(source), line: 1, column: 1)
}

pub fn iterator(scanner: Scanner) -> Iterator(Token) {
  use scanner <- iterator.unfold(from: scanner)
  case next(scanner) {
    #(_scanner, Token(token_type: token.Eof, ..)) -> iterator.Done
    #(scanner, token) -> iterator.Next(element: token, accumulator: scanner)
  }
}

pub fn scan(scanner: Scanner) -> List(Token) {
  iterator(scanner)
  |> iterator.to_list()
}

pub fn next(scanner: Scanner) -> #(Scanner, Token) {
  let line = scanner.line
  let column = scanner.column

  case scanner.graphemes {
    // eof
    [] -> #(scanner, token.eof(line, column))

    // newline ("\r\n" is considered a single grapheme)
    ["\r\n", ..rest] | ["\n", ..rest] ->
      Scanner(graphemes: rest, column: 1, line: scanner.line + 1)
      |> next

    // whitespace
    [" ", ..] | ["\t", ..] | ["\r", ..] ->
      scanner
      |> advance(by: 1)
      |> next

    // comment
    ["/", "/", ..rest] ->
      scanner
      |> drop_comment(rest, 2)
      |> next

    // parenthesis
    ["(", ..] -> #(
      advance(scanner, by: 1),
      token.left_paren(scanner.line, scanner.column),
    )
    [")", ..] -> #(advance(scanner, by: 1), token.right_paren(line, column))
    ["{", ..] -> #(advance(scanner, by: 1), token.left_brace(line, column))
    ["}", ..] -> #(advance(scanner, by: 1), token.right_brace(line, column))

    // arithmetic
    ["+", ..] -> #(advance(scanner, by: 1), token.plus(line, column))
    ["-", ..] -> #(advance(scanner, by: 1), token.minus(line, column))
    ["*", ..] -> #(advance(scanner, by: 1), token.star(line, column))
    ["/", ..] -> #(advance(scanner, by: 1), token.slash(line, column))

    // comparisons
    ["=", "=", ..] -> #(
      advance(scanner, by: 2),
      token.equal_equal(line, column),
    )
    ["!", "=", ..] -> #(advance(scanner, by: 2), token.bang_equal(line, column))
    [">", "=", ..] -> #(
      advance(scanner, by: 2),
      token.greater_equal(line, column),
    )
    [">", ..] -> #(advance(scanner, by: 1), token.greater(line, column))
    ["<", "=", ..] -> #(advance(scanner, by: 2), token.less_equal(line, column))
    ["<", ..] -> #(advance(scanner, by: 1), token.less(line, column))

    // punctuation
    [",", ..] -> #(advance(scanner, by: 1), token.comma(line, column))
    [";", ..] -> #(advance(scanner, by: 1), token.semicolon(line, column))
    [".", ..] -> #(advance(scanner, by: 1), token.dot(line, column))
    ["!", ..] -> #(advance(scanner, by: 1), token.bang(line, column))

    // equal
    ["=", ..] -> #(advance(scanner, by: 1), token.equal(line, column))

    // numbers
    ["0" as digit, ..rest]
    | ["1" as digit, ..rest]
    | ["2" as digit, ..rest]
    | ["3" as digit, ..rest]
    | ["4" as digit, ..rest]
    | ["5" as digit, ..rest]
    | ["6" as digit, ..rest]
    | ["7" as digit, ..rest]
    | ["8" as digit, ..rest]
    | ["9" as digit, ..rest] ->
      string_builder.new()
      |> string_builder.append(digit)
      |> scan_number(scanner, rest, 1, True)

    // literal strings (escaping is not allowed)
    ["\"", ..rest] ->
      scan_string(string_builder.new(), scanner, rest, scanner.column + 1, 1)

    // keywords and identifiers
    [grapheme, ..rest] -> {
      case is_identifier(grapheme) {
        True ->
          string_builder.new()
          |> string_builder.append(grapheme)
          |> scan_identifier(scanner, rest, 1)
        False -> todo("error!")
      }
    }

    _ -> todo("error!!")
  }
}

fn is_identifier(grapheme: String) -> Bool {
  string_extra.is_alphanum(grapheme) || grapheme == "_"
}

fn advance(scanner: Scanner, by offset: Int) -> Scanner {
  let rest = list.drop(scanner.graphemes, up_to: offset)
  update_scanner(scanner, rest, offset)
}

fn update_scanner(
  scanner: Scanner,
  new_graphemes: List(String),
  advance_column: Int,
) -> Scanner {
  Scanner(
    graphemes: new_graphemes,
    column: scanner.column + advance_column,
    line: scanner.line,
  )
}

fn drop_comment(
  scanner: Scanner,
  rest: List(String),
  comment_length: Int,
) -> Scanner {
  case rest {
    [] -> update_scanner(scanner, rest, comment_length)
    ["\n", ..rest] | ["\r\n", ..rest] ->
      Scanner(graphemes: rest, line: scanner.line + 1, column: 1)
    [_, ..rest] -> drop_comment(scanner, rest, comment_length + 1)
  }
}

fn scan_number(
  number_so_far: StringBuilder,
  scanner: Scanner,
  rest: List(String),
  number_length: Int,
  is_int: Bool,
) -> #(Scanner, Token) {
  case rest {
    // Only if a dot was not already encountered
    ["." as dot, ..rest] if is_int ->
      number_so_far
      |> string_builder.append(dot)
      |> scan_number(scanner, rest, number_length + 1, False)

    ["0" as digit, ..rest]
    | ["1" as digit, ..rest]
    | ["2" as digit, ..rest]
    | ["3" as digit, ..rest]
    | ["4" as digit, ..rest]
    | ["5" as digit, ..rest]
    | ["6" as digit, ..rest]
    | ["7" as digit, ..rest]
    | ["8" as digit, ..rest]
    | ["9" as digit, ..rest] ->
      number_so_far
      |> string_builder.append(digit)
      |> scan_number(scanner, rest, number_length + 1, is_int)

    // Anything else means the number is terminated
    _ -> #(
      update_scanner(scanner, rest, number_length),
      Token(
        token_type: number_so_far
        |> string_builder.to_string
        |> token.Number,
        span: span.single_line(
          on: scanner.line,
          starts_at: scanner.column,
          ends_at: scanner.column + number_length - 1,
        ),
      ),
    )
  }
}

fn scan_string(
  string_so_far: StringBuilder,
  scanner: Scanner,
  rest: List(String),
  column_end: Int,
  lines: Int,
) -> #(Scanner, Token) {
  case rest {
    ["\"", ..rest] -> #(
      Scanner(
        graphemes: rest,
        column: column_end + 1,
        line: scanner.line + lines - 1,
      ),
      Token(
        token_type: string_so_far
        |> string_builder.to_string
        |> token.String,
        span: Span(
          column_start: scanner.column,
          column_end: column_end,
          line_start: scanner.line,
          line_end: scanner.line + lines - 1,
        ),
      ),
    )

    ["\n" as grapheme, ..rest] | ["\r\n" as grapheme, ..rest] ->
      string_so_far
      |> string_builder.append(grapheme)
      |> scan_string(scanner, rest, 1, lines + 1)

    [grapheme, ..rest] ->
      string_so_far
      |> string_builder.append(grapheme)
      |> scan_string(scanner, rest, column_end + 1, lines)

    [] -> todo("Unterminated string")
  }
}

fn scan_identifier(
  identifier_so_far: StringBuilder,
  scanner: Scanner,
  rest: List(String),
  identifier_length: Int,
) -> #(Scanner, Token) {
  case rest {
    [] -> #(
      update_scanner(scanner, rest, identifier_length),
      make_identifier_token(identifier_so_far, scanner, identifier_length),
    )

    [grapheme, ..rest] as graphemes ->
      case is_identifier(grapheme) {
        True ->
          identifier_so_far
          |> string_builder.append(grapheme)
          |> scan_identifier(scanner, rest, identifier_length + 1)

        False -> #(
          update_scanner(scanner, graphemes, identifier_length),
          make_identifier_token(identifier_so_far, scanner, identifier_length),
        )
      }
  }
}

fn make_identifier_token(
  identifier: StringBuilder,
  scanner: Scanner,
  identifier_length: Int,
) -> Token {
  let token_type = case string_builder.to_string(identifier) {
    "and" -> token.And
    "class" -> token.Class
    "else" -> token.Else
    "false" -> token.False
    "fun" -> token.Fun
    "for" -> token.For
    "if" -> token.If
    "nil" -> token.Nil
    "or" -> token.Or
    "print" -> token.Print
    "return" -> token.Return
    "super" -> token.Super
    "this" -> token.This
    "true" -> token.True
    "var" -> token.Var
    "while" -> token.While
    name -> token.Identifier(name)
  }
  Token(
    token_type: token_type,
    span: span.single_line(
      on: scanner.line,
      starts_at: scanner.column,
      ends_at: scanner.column + identifier_length - 1,
    ),
  )
}
