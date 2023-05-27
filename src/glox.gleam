import gleam/erlang
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glox/scanner
import glox/parser
import glox/expression
import gleam/pair
import gleam/iterator
import glox/internal/result_extra

pub fn main() {
  run_prompt()
}

fn run_prompt() {
  use line <- result.try(erlang.get_line("> "))
  case string.trim(line) {
    "" -> Ok(Nil)
    trimmed -> {
      run(trimmed)
      run_prompt()
    }
  }
}

fn run(source: String) {
  source
  |> scanner.new
  |> scanner.scan
  |> result_extra.from_list_pair
  |> result.unwrap(or: [])
  |> iterator.from_list
  |> parser.parse
  |> pair.first
  |> result.map(expression.to_string)
  |> io.debug
}
