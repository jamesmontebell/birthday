-module(birthday).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([main/0]).

-spec main() -> nil.
main() ->
    wisp:configure_logger(),
    Secret_key_base = wisp:random_string(64),
    _assert_subject = begin
        _pipe = wisp:mist_handler(
            fun app@router:handle_request/1,
            Secret_key_base
        ),
        _pipe@1 = mist:new(_pipe),
        _pipe@2 = mist:port(_pipe@1, 8000),
        mist:start_http(_pipe@2)
    end,
    {ok, _} = case _assert_subject of
        {ok, _} -> _assert_subject;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Assertion pattern match failed"/utf8>>,
                        value => _assert_fail,
                        module => <<"birthday"/utf8>>,
                        function => <<"main"/utf8>>,
                        line => 16})
    end,
    gleam_erlang_ffi:sleep_forever().
