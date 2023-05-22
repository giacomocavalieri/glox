import gleam/erlang
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glox/scanner

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
  |> list.each(io.debug)
}
