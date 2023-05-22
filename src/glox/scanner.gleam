import glox/token.{Token}
import gleam/string
import gleam/iterator.{Iterator}
import gleam/list
import gleam/string_builder.{StringBuilder}
import glox/span.{Span}
import glox/internal/string_extra

/// A scanner used to scan Lox code.
/// While behaving like the Loc scanner described in
/// "Crafting Interpreters" it implemented quite differently:
/// the scanner is purely functional and does not rely on
/// mutable state.
pub opaque type Scanner {
  // A scanner has a list of graphemes that is the source and
  // tracks the current line and column during the scanning
  // process.
  //
  // This is the first difference with "Crafting Interpreters",
  // I keep track of the column as well as the line to (hopefully)
  // provide better error messages.
  Scanner(graphemes: List(String), line: Int, column: Int)
}

/// Create a new scanner given a source string.
pub fn new(source: String) -> Scanner {
  // A new scanner is built by splitting the source code in graphemes
  // and the initial position is at line 1, column 1 of the source.
  Scanner(graphemes: string.to_graphemes(source), line: 1, column: 1)
}

/// Get a stream of tokens from a scanner.
pub fn iterator(scanner: Scanner) -> Iterator(Token) {
  // Keep calling the `next` function until Eof is reached.
  // `next` also provides the new state for the scanning process
  // to continue, that is why the new scanner is used as the
  // accumulator for the next unfolding step
  use scanner <- iterator.unfold(from: scanner)
  case next(scanner) {
    #(_scanner, Token(token_type: token.Eof, ..)) -> iterator.Done
    #(scanner, token) -> iterator.Next(element: token, accumulator: scanner)
  }
}

/// Get a list of tokens from a scanner.
///
/// # Examples
/// ```gleam
/// "()"
/// |> scanner.new
/// |> scanner.scan
/// // [
/// //   Token(LeftParen, Span(1, 1, 1, 1)),
/// //   Token(RightParen, Span(1, 1, 2, 2)),
/// // ]
/// ```
pub fn scan(scanner: Scanner) -> List(Token) {
  iterator(scanner)
  |> iterator.to_list()
}

/// Scans the scanner's input and returns the next token it finds.
/// Also returns the updated scanner updating the current line and
/// column according to the scanned token.
pub fn next(scanner: Scanner) -> #(Scanner, Token) {
  let line = scanner.line
  let column = scanner.column

  // Pattern match on the list of graphemes to find the next token.
  case scanner.graphemes {
    // If there's no graphemes left in the source code
    // return the EOF token.
    [] -> #(scanner, token.eof(line, column))

    // All newlines are ignored but the state of the scanner must
    // be updated to take into account the new line: the column
    // starts back at 1 while the line is incremented.
    // ("\r\n" is considered a single grapheme)
    // Since a token must still be returned by a call to `next`,
    // recursivley call it on the new scanner to return a token.
    ["\r\n", ..rest] | ["\n", ..rest] ->
      Scanner(graphemes: rest, column: 1, line: line + 1)
      |> next

    // All whitespaces are ignored. The behaviour is analogous to
    // the whitespace case: we still need to return a valid token
    // so we increase the scanner's current column by 1 (calling
    // `advance`) and pass this new scanner to a recursive call
    // to `next`. 
    [" ", ..] | ["\t", ..] | ["\r", ..] -> next(advance(scanner, by: 1))

    // Comments are discarded as well. Again, the behaviour is
    // analogous to the previous two cases: we update the status
    // of the scanner and recursively call `next`.
    // The starting lenght is 2 to take into account the "//".
    ["/", "/", ..rest] -> next(drop_comment(line, column, rest, 2))

    // Now there's a series of basic tokens: parenthesis, arithmetic operators,
    // comparison operators, etc.
    // If we see the graphemes corresponding to one of these tokens, we advance
    // the scanner based on its fixed size of each token and return it.
    //
    // Take for example the `LeftParen` token: when we pattern match on its single
    // grapheme (that is "(") we advance the scanner by one and return the corresponding
    // token: Token(token_type: LeftParen, ...)
    // If a token is composed by two graphemes instead of one (like the "=="), we just
    // advance the scanner's column by 2 positions istead of one.
    //
    // As a last note: notice how the order of the pattern maching branches is fundamental!
    // The ["=", "=", ..] branch _must_ be placed before the ["=", ..] branch. This is
    // necessary in order to get maximal matching: if the branch matching on the `Equal`
    // token came first, any sequence of two consecutive equals would be matched as a pair
    // of `Equal` tokens instead of an `EqualEqual` token.
    // The same concept applies for a couple more tokens: > and >=, ! and !=, < and <=.
    ["(", ..] -> #(advance(scanner, by: 1), token.left_paren(line, column))
    [")", ..] -> #(advance(scanner, by: 1), token.right_paren(line, column))
    ["{", ..] -> #(advance(scanner, by: 1), token.left_brace(line, column))
    ["}", ..] -> #(advance(scanner, by: 1), token.right_brace(line, column))
    ["+", ..] -> #(advance(scanner, by: 1), token.plus(line, column))
    ["-", ..] -> #(advance(scanner, by: 1), token.minus(line, column))
    ["*", ..] -> #(advance(scanner, by: 1), token.star(line, column))
    ["/", ..] -> #(advance(scanner, by: 1), token.slash(line, column))
    ["=", "=", ..] -> #(advance(scanner, 2), token.equal_equal(line, column))
    ["!", "=", ..] -> #(advance(scanner, by: 2), token.bang_equal(line, column))
    [">", "=", ..] -> #(advance(scanner, 2), token.greater_equal(line, column))
    [">", ..] -> #(advance(scanner, by: 1), token.greater(line, column))
    ["<", "=", ..] -> #(advance(scanner, by: 2), token.less_equal(line, column))
    ["<", ..] -> #(advance(scanner, by: 1), token.less(line, column))
    [",", ..] -> #(advance(scanner, by: 1), token.comma(line, column))
    [";", ..] -> #(advance(scanner, by: 1), token.semicolon(line, column))
    [".", ..] -> #(advance(scanner, by: 1), token.dot(line, column))
    ["!", ..] -> #(advance(scanner, by: 1), token.bang(line, column))
    ["=", ..] -> #(advance(scanner, by: 1), token.equal(line, column))

    // Whenever we meet a digit we switch to number scanning. The first digit is
    // turned into a `StringBuilder` and then passed to the `scan_number` function
    // that does all the hard job. 
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
      |> scan_number(line, column, rest, 1, True)

    // If we meet a " we switch to string scanning.
    // All the hard work is done by the `scan_string` function.
    ["\"", ..rest] ->
      scan_string(string_builder.new(), line, column, rest, column + 1, 1)

    // If everything else fails we try to scan an identifier or a keyword.
    [grapheme, ..rest] -> {
      case is_identifier(grapheme) {
        // If the grapheme is allowed to appear in an identifier we switch
        // to identifier/keyword scanning. The grapheme is turned into a
        // `StringBuilder` that is then passed to `scan_identifier` that
        // does all the hard work. 
        True ->
          string_builder.new()
          |> string_builder.append(grapheme)
          |> scan_identifier(line, column, rest, 1)

        // If the grapheme can not belong to an identifier either then we fail
        // with an error.
        False -> todo("error!")
      }
    }
  }
}

fn is_identifier(grapheme: String) -> Bool {
  // A grapheme can be part of an identifier only if it is alphanumeric
  // or an underscore (basically a regex like [a-zA-Z_]).
  string_extra.is_alphanum(grapheme) || grapheme == "_"
}

/// Advance the scanner by dropping a number of graphemes from the source code
/// equal to the given offset. The column number is also updated accordingly.
fn advance(scanner: Scanner, by offset: Int) -> Scanner {
  Scanner(
    graphemes: list.drop(scanner.graphemes, up_to: offset),
    column: scanner.column + offset,
    line: scanner.line,
  )
}

/// This function keeps dropping characters from the current line until it meets a newline
/// (that is also dropped) or the end of file.
/// If the newline is met it updates the scanner's line by increasing it and reset the
/// current column to 1 (just as if it met a newline).
/// If the end of file is met it uses the `comment_length` to report its correct position
/// in the file.
fn drop_comment(
  line: Int,
  column_start: Int,
  source: List(String),
  comment_length: Int,
) -> Scanner {
  case source {
    ["\n", ..rest] | ["\r\n", ..rest] ->
      Scanner(graphemes: rest, line: line + 1, column: 1)
    [_, ..rest] -> drop_comment(line, column_start, rest, comment_length + 1)
    [] ->
      Scanner(
        graphemes: source,
        line: line,
        column: column_start + comment_length,
      )
  }
}

fn scan_number(
  number: StringBuilder,
  line: Int,
  column_start: Int,
  source: List(String),
  number_length: Int,
  is_int: Bool,
) -> #(Scanner, Token) {
  case source {
    // If a dot is met and it was not previously met (that is `is_int` is True)
    // the dot is appended to the number being scanned and the scanning
    // continues.
    ["." as dot, ..rest] if is_int ->
      number
      |> string_builder.append(dot)
      |> scan_number(line, column_start, rest, number_length + 1, False)

    // If a digit is met it is appended to the number being scanned
    // and the scanning continues.
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
      number
      |> string_builder.append(digit)
      |> scan_number(line, column_start, rest, number_length + 1, is_int)

    // Anything other grapheme signals that the number is terminated
    // so the scanner is updated by increasing the column by the number length.
    // One could also get the number length by calling `string.length` but since
    // it's linear on the string size I've opted to carry around the additional
    // parameter `number_length` to avoid scanning the string twice.
    _ -> #(
      Scanner(
        graphemes: source,
        column: column_start + number_length,
        line: line,
      ),
      Token(
        token_type: number
        |> string_builder.to_string
        |> token.Number,
        span: span.single_line(
          on: line,
          starts_at: column_start,
          ends_at: column_start + number_length - 1,
        ),
      ),
    )
  }
}

fn scan_string(
  string: StringBuilder,
  line_start: Int,
  column_start: Int,
  source: List(String),
  column_end: Int,
  lines: Int,
) -> #(Scanner, Token) {
  // This function is a bit more complicated than what I would have liked
  // in order to take into account multiline strings (that are permitted
  // in the Lox language). Having multiline strings makes it more complex
  // to track the correct span: the starting column must be the one
  // of the first ", the ending column must be the one of the last ",
  // the starting line must be the one where the first " is met, the ending
  // line must be the one where the last " is met.
  //
  // The starting line and column are provided by the first caller of
  // `scan_string` and never change throught the recursive calls, they are
  // just used at the end to create the correct span and updated scanner.
  //
  // The ending column is updated as the string is scanned to correctly take
  // into account any newlines.
  case source {
    // If we meet " it means the string has ended, we create the token
    // and an updated with the remaining graphemes.
    ["\"", ..rest] -> #(
      Scanner(
        graphemes: rest,
        column: column_end + 1,
        line: line_start + lines - 1,
      ),
      Token(
        token_type: string
        |> string_builder.to_string
        |> token.String,
        span: Span(
          column_start: column_start,
          column_end: column_end,
          line_start: line_start,
          line_end: line_start + lines - 1,
        ),
      ),
    )

    // If a newline is met, the number of lines is increased, the final
    // column starts back at 1 and it is then appended to the string being
    // built.
    ["\n" as grapheme, ..rest] | ["\r\n" as grapheme, ..rest] ->
      string
      |> string_builder.append(grapheme)
      |> scan_string(line_start, column_start, rest, 1, lines + 1)

    // Any other char is appended to the string increasing `column_end`.
    [grapheme, ..rest] ->
      string
      |> string_builder.append(grapheme)
      |> scan_string(line_start, column_start, rest, column_end + 1, lines)

    // If the end of file is met before finding the closing " there's a syntax
    // error.
    [] -> todo("Unterminated string")
  }
}

fn scan_identifier(
  identifier: StringBuilder,
  line: Int,
  column_start: Int,
  source: List(String),
  identifier_length: Int,
) -> #(Scanner, Token) {
  case source {
    // If the end of file is met it means that the identifier is over.
    // It is built from the `identifier` and an updated scanner is returned.
    [] -> #(
      Scanner(
        graphemes: source,
        line: line,
        column: column_start + identifier_length,
      ),
      identifier_token(identifier, line, column_start, identifier_length),
    )

    [grapheme, ..rest] ->
      case is_identifier(grapheme) {
        // If the grapheme can belong to an identifier it is appended to the
        // identifier being scanned and its size is increased. (Here I have
        // opted for the same trick to pass along the size of the identifier
        // to avoid having to compute it once more once the entire string
        // is built).
        True ->
          identifier
          |> string_builder.append(grapheme)
          |> scan_identifier(line, column_start, rest, identifier_length + 1)

        // If the grapheme can not belong to an identifier the identifier is
        // over and is returned without consuming the grapheme that is not
        // part of the identifier. This branch is exactly the same as the
        // end of file a couple of lines above.
        False -> #(
          Scanner(
            graphemes: source,
            line: line,
            column: column_start + identifier_length,
          ),
          identifier_token(identifier, line, column_start, identifier_length),
        )
      }
  }
}

fn identifier_token(
  identifier: StringBuilder,
  line: Int,
  column: Int,
  identifier_length: Int,
) -> Token {
  // Given an identifier string it returns its corresponding token
  // that could either be a keyword token (like and, or, etc.) or just
  // an identifier.
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
      on: line,
      starts_at: column,
      ends_at: column + identifier_length - 1,
    ),
  )
}
