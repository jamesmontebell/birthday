-module(app@router).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([handle_request/1]).

-spec home_page(gleam@http@request:request(wisp:connection())) -> gleam@http@response:response(wisp:body()).
home_page(Req) ->
    wisp:require_method(
        Req,
        get,
        fun() ->
            Html = gleam@string_builder:from_string(<<"Hello, Joe!"/utf8>>),
            _pipe = wisp:ok(),
            wisp:html_body(_pipe, Html)
        end
    ).

-spec show_birthday() -> gleam@http@response:response(wisp:body()).
show_birthday() ->
    Html = gleam@string_builder:from_string(
        <<"<div class='bg-pink-500 py-2 px-4 rounded'>Happy Birthday! 🎉</div>"/utf8>>
    ),
    _pipe = wisp:ok(),
    _pipe@1 = fun gleam@http@response:set_header/3(
        _pipe,
        <<"Access-Control-Allow-Origin"/utf8>>,
        <<"*"/utf8>>
    ),
    _pipe@2 = fun gleam@http@response:set_header/3(
        _pipe@1,
        <<"Access-Control-Allow-Methods"/utf8>>,
        <<"GET, OPTIONS"/utf8>>
    ),
    _pipe@3 = fun gleam@http@response:set_header/3(
        _pipe@2,
        <<"Access-Control-Allow-Headers"/utf8>>,
        <<"Content-Type, hx-request, hx-target, hx-current-url"/utf8>>
    ),
    _pipe@4 = fun gleam@http@response:set_header/3(
        _pipe@3,
        <<"Content-Type"/utf8>>,
        <<"text/html"/utf8>>
    ),
    wisp:html_body(_pipe@4, Html).

-spec birthday(gleam@http@request:request(wisp:connection())) -> gleam@http@response:response(wisp:body()).
birthday(Req) ->
    case erlang:element(2, Req) of
        options ->
            show_birthday();

        get ->
            show_birthday();

        _ ->
            wisp:method_not_allowed([])
    end.

-spec handle_request(gleam@http@request:request(wisp:connection())) -> gleam@http@response:response(wisp:body()).
handle_request(Req) ->
    app@web:middleware(
        Req,
        fun(_) -> case fun gleam@http@request:path_segments/1(Req) of
                [] ->
                    home_page(Req);

                [<<"birthday"/utf8>>] ->
                    birthday(Req);

                _ ->
                    wisp:not_found()
            end end
    ).
