import wisp.{type Request, type Response}
import gleam/string_builder
import gleam/http.{Get, Options}
import app/web

pub fn handle_request(req: Request) -> Response {
  use _req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> home_page(req)
    ["birthday"] -> birthday(req)
    _ -> wisp.not_found()
  }
}

fn home_page(req: Request) -> Response {
  use <- wisp.require_method(req, Get)
  let html = string_builder.from_string("Hello, Joe!")
  wisp.ok()
  |> wisp.html_body(html)
}

fn birthday(req: Request) -> Response {
  case req.method {
    Options -> show_birthday()
    Get -> show_birthday()
    _ -> wisp.method_not_allowed([])
  }
}

fn show_birthday() -> Response {
  let html =
    string_builder.from_string(
      "<div class='bg-pink-500 py-2 px-4 rounded'>Happy Birthday! 🎉</div>",
    )
  wisp.ok()
  |> wisp.set_header("Access-Control-Allow-Origin", "*")
  |> wisp.set_header("Access-Control-Allow-Methods", "GET, OPTIONS")
  |> wisp.set_header(
    "Access-Control-Allow-Headers",
    "Content-Type, hx-request, hx-target, hx-current-url",
  )
  |> wisp.set_header("Content-Type", "text/html")
  |> wisp.html_body(html)
}
