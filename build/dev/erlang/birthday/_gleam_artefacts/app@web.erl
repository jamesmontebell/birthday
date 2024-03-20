-module(app@web).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([middleware/2]).

-spec middleware(
    gleam@http@request:request(wisp:connection()),
    fun((gleam@http@request:request(wisp:connection())) -> gleam@http@response:response(wisp:body()))
) -> gleam@http@response:response(wisp:body()).
middleware(Req, Handle_request) ->
    Req@1 = wisp:method_override(Req),
    wisp:log_request(
        Req@1,
        fun() ->
            wisp:rescue_crashes(
                fun() ->
                    wisp:handle_head(
                        Req@1,
                        fun(Req@2) -> Handle_request(Req@2) end
                    )
                end
            )
        end
    ).
