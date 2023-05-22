import glox/token.{Token}

pub type Expression {
  Binary(left: Expression, operator: Token, right: Expression)
  Grouping(expression: Expression)
  Literal(value: Token)
  Unary(operator: Token, expression: Expression)
}
