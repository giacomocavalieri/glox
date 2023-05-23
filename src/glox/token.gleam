import glox/span.{Span}

pub type TokenType {
  // Single char tokens
  LeftParen
  RightParen
  LeftBrace
  RightBrace
  Comma
  Dot
  Minus
  Plus
  Semicolon
  Slash
  Star

  // One or two char tokens
  Bang
  BangEqual
  Equal
  EqualEqual
  Greater
  GreaterEqual
  Less
  LessEqual

  // Literals
  Identifier(value: String)
  String(value: String)
  Number(value: String)

  // Keywords
  And
  Class
  Else
  False
  Fun
  For
  If
  Nil
  Or
  Print
  Return
  Super
  This
  True
  Var
  While

  Eof
}

pub type Token {
  Token(token_type: TokenType, span: Span)
}

pub fn lexeme(token: Token) -> String {
  case token.token_type {
    Eof -> ""
    LeftParen -> "("
    RightParen -> ")"
    LeftBrace -> "{"
    RightBrace -> "}"
    Comma -> ","
    Dot -> "."
    Semicolon -> ";"
    Plus -> "+"
    Minus -> "-"
    Star -> "*"
    Slash -> "/"
    Bang -> "!"
    BangEqual -> "!="
    Equal -> "="
    EqualEqual -> "=="
    Greater -> ">"
    GreaterEqual -> ">="
    Less -> "<"
    LessEqual -> "<="
    And -> "and"
    Class -> "class"
    Else -> "else"
    False -> "false"
    Fun -> "fun"
    For -> "for"
    If -> "if"
    Nil -> "nil"
    Or -> "or"
    Print -> "print"
    Return -> "return"
    Super -> "super"
    This -> "this"
    True -> "true"
    Var -> "var"
    While -> "while"
    Identifier(value) -> value
    String(value) -> value
    Number(value) -> value
  }
}

pub fn left_paren(line: Int, column: Int) -> Token {
  single_line_token(LeftParen, line, column, column)
}

pub fn right_paren(line: Int, column: Int) -> Token {
  single_line_token(RightParen, line, column, column)
}

pub fn left_brace(line: Int, column: Int) -> Token {
  single_line_token(LeftBrace, line, column, column)
}

pub fn right_brace(line: Int, column: Int) -> Token {
  single_line_token(RightBrace, line, column, column)
}

pub fn comma(line: Int, column: Int) -> Token {
  single_line_token(Comma, line, column, column)
}

pub fn dot(line: Int, column: Int) -> Token {
  single_line_token(Dot, line, column, column)
}

pub fn semicolon(line: Int, column: Int) -> Token {
  single_line_token(Semicolon, line, column, column)
}

pub fn minus(line: Int, column: Int) -> Token {
  single_line_token(Minus, line, column, column)
}

pub fn plus(line: Int, column: Int) -> Token {
  single_line_token(Plus, line, column, column)
}

pub fn slash(line: Int, column: Int) -> Token {
  single_line_token(Slash, line, column, column)
}

pub fn star(line: Int, column: Int) -> Token {
  single_line_token(Star, line, column, column)
}

pub fn bang(line: Int, column: Int) -> Token {
  single_line_token(Bang, line, column, column)
}

pub fn bang_equal(line: Int, column: Int) -> Token {
  single_line_token(BangEqual, line, column, column + 1)
}

pub fn equal(line: Int, column: Int) -> Token {
  single_line_token(Equal, line, column, column)
}

pub fn equal_equal(line: Int, column: Int) -> Token {
  single_line_token(EqualEqual, line, column, column + 1)
}

pub fn greater(line: Int, column: Int) -> Token {
  single_line_token(Greater, line, column, column)
}

pub fn greater_equal(line: Int, column: Int) -> Token {
  single_line_token(GreaterEqual, line, column, column + 1)
}

pub fn less(line: Int, column: Int) -> Token {
  single_line_token(Less, line, column, column)
}

pub fn less_equal(line: Int, column: Int) -> Token {
  single_line_token(LessEqual, line, column, column + 1)
}

pub fn and(line: Int, column: Int) -> Token {
  single_line_token(And, line, column, column + 2)
}

pub fn class(line: Int, column: Int) -> Token {
  single_line_token(Class, line, column, column + 3)
}

pub fn else(line: Int, column: Int) -> Token {
  single_line_token(Else, line, column, column + 3)
}

pub fn false(line: Int, column: Int) -> Token {
  single_line_token(False, line, column, column + 4)
}

pub fn fun(line: Int, column: Int) -> Token {
  single_line_token(Fun, line, column, column + 2)
}

pub fn for(line: Int, column: Int) -> Token {
  single_line_token(For, line, column, column + 2)
}

pub fn if_(line: Int, column: Int) -> Token {
  single_line_token(If, line, column, column + 1)
}

pub fn nil(line: Int, column: Int) -> Token {
  single_line_token(Nil, line, column, column + 2)
}

pub fn or(line: Int, column: Int) -> Token {
  single_line_token(Or, line, column, column + 1)
}

pub fn print(line: Int, column: Int) -> Token {
  single_line_token(Print, line, column, column + 4)
}

pub fn return(line: Int, column: Int) -> Token {
  single_line_token(Return, line, column, column + 5)
}

pub fn super(line: Int, column: Int) -> Token {
  single_line_token(Super, line, column, column + 4)
}

pub fn this(line: Int, column: Int) -> Token {
  single_line_token(This, line, column, column + 3)
}

pub fn true(line: Int, column: Int) -> Token {
  single_line_token(True, line, column, column + 3)
}

pub fn var(line: Int, column: Int) -> Token {
  single_line_token(Var, line, column, column + 2)
}

pub fn while(line: Int, column: Int) -> Token {
  single_line_token(While, line, column, column + 4)
}

pub fn eof(line: Int, column: Int) -> Token {
  single_line_token(Eof, line, column, column)
}

fn single_line_token(
  token_type: TokenType,
  line: Int,
  start_column: Int,
  end_column: Int,
) {
  Token(
    token_type: token_type,
    span: span.single_line(
      on: line,
      starts_at: start_column,
      ends_at: end_column,
    ),
  )
}
