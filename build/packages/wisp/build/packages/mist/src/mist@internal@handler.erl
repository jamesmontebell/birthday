-module(mist@internal@handler).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([new_state/0, with_func/1]).
-export_type([response_data/0, handler_error/0, state/0]).

-type response_data() :: {websocket,
        gleam@erlang@process:selector(gleam@erlang@process:process_down())} |
    {bytes, gleam@bytes_builder:bytes_builder()} |
    {chunked, gleam@iterator:iterator(gleam@bytes_builder:bytes_builder())} |
    {file, mist@internal@file:file_descriptor(), integer(), integer()}.

-type handler_error() :: {invalid_request, mist@internal@http:decode_error()} |
    not_found.

-type state() :: {state, gleam@option:option(gleam@erlang@process:timer())}.

-spec new_state() -> state().
new_state() ->
    {state, none}.

-spec log_and_error(
    gleam@erlang:crash(),
    glisten@socket:socket(),
    glisten@socket@transport:transport()
) -> gleam@otp@actor:next(glisten:message(any()), state()).
log_and_error(Error, Socket, Transport) ->
    case Error of
        {exited, Msg} ->
            mist@internal@logger:error(Error),
            _pipe = gleam@http@response:new(500),
            _pipe@1 = gleam@http@response:set_body(
                _pipe,
                gleam_stdlib:wrap_list(<<"Internal Server Error"/utf8>>)
            ),
            _pipe@2 = gleam@http@response:prepend_header(
                _pipe@1,
                <<"content-length"/utf8>>,
                <<"21"/utf8>>
            ),
            _pipe@3 = mist@internal@http:add_default_headers(_pipe@2),
            _pipe@4 = mist@internal@encoder:to_bytes_builder(_pipe@3),
            (erlang:element(12, Transport))(Socket, _pipe@4),
            _ = (erlang:element(4, Transport))(Socket),
            {stop, {abnormal, gleam@dynamic:unsafe_coerce(Msg)}};

        {thrown, Msg} ->
            mist@internal@logger:error(Error),
            _pipe = gleam@http@response:new(500),
            _pipe@1 = gleam@http@response:set_body(
                _pipe,
                gleam_stdlib:wrap_list(<<"Internal Server Error"/utf8>>)
            ),
            _pipe@2 = gleam@http@response:prepend_header(
                _pipe@1,
                <<"content-length"/utf8>>,
                <<"21"/utf8>>
            ),
            _pipe@3 = mist@internal@http:add_default_headers(_pipe@2),
            _pipe@4 = mist@internal@encoder:to_bytes_builder(_pipe@3),
            (erlang:element(12, Transport))(Socket, _pipe@4),
            _ = (erlang:element(4, Transport))(Socket),
            {stop, {abnormal, gleam@dynamic:unsafe_coerce(Msg)}};

        {errored, Msg} ->
            mist@internal@logger:error(Error),
            _pipe = gleam@http@response:new(500),
            _pipe@1 = gleam@http@response:set_body(
                _pipe,
                gleam_stdlib:wrap_list(<<"Internal Server Error"/utf8>>)
            ),
            _pipe@2 = gleam@http@response:prepend_header(
                _pipe@1,
                <<"content-length"/utf8>>,
                <<"21"/utf8>>
            ),
            _pipe@3 = mist@internal@http:add_default_headers(_pipe@2),
            _pipe@4 = mist@internal@encoder:to_bytes_builder(_pipe@3),
            (erlang:element(12, Transport))(Socket, _pipe@4),
            _ = (erlang:element(4, Transport))(Socket),
            {stop, {abnormal, gleam@dynamic:unsafe_coerce(Msg)}}
    end.

-spec handle_bytes_builder_body(
    gleam@http@response:response(response_data()),
    gleam@bytes_builder:bytes_builder(),
    mist@internal@http:connection()
) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
handle_bytes_builder_body(Resp, Body, Conn) ->
    _pipe = Resp,
    _pipe@1 = gleam@http@response:set_body(_pipe, Body),
    _pipe@2 = mist@internal@http:add_default_headers(_pipe@1),
    _pipe@3 = mist@internal@encoder:to_bytes_builder(_pipe@2),
    (erlang:element(12, erlang:element(4, Conn)))(
        erlang:element(3, Conn),
        _pipe@3
    ).

-spec handle_file_body(
    gleam@http@response:response(response_data()),
    mist@internal@http:connection()
) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
handle_file_body(Resp, Conn) ->
    _assert_subject = erlang:element(4, Resp),
    {file, File_descriptor, Offset, Length} = case _assert_subject of
        {file, _, _, _} -> _assert_subject;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Assertion pattern match failed"/utf8>>,
                        value => _assert_fail,
                        module => <<"mist/internal/handler"/utf8>>,
                        function => <<"handle_file_body"/utf8>>,
                        line => 204})
    end,
    _pipe = Resp,
    _pipe@1 = gleam@http@response:prepend_header(
        _pipe,
        <<"content-length"/utf8>>,
        gleam@int:to_string(Length - Offset)
    ),
    _pipe@2 = gleam@http@response:set_body(_pipe@1, gleam@bytes_builder:new()),
    _pipe@3 = (fun(R) ->
        mist@internal@encoder:response_builder(
            erlang:element(2, Resp),
            erlang:element(3, R)
        )
    end)(_pipe@2),
    _pipe@4 = (erlang:element(12, erlang:element(4, Conn)))(
        erlang:element(3, Conn),
        _pipe@3
    ),
    _pipe@7 = gleam@result:then(
        _pipe@4,
        fun(_) ->
            _pipe@5 = file:sendfile(
                File_descriptor,
                erlang:element(3, Conn),
                Offset,
                Length,
                []
            ),
            _pipe@6 = gleam@result:map_error(
                _pipe@5,
                fun(Err) ->
                    mist@internal@logger:error(
                        {<<"Failed to send file"/utf8>>, Err}
                    )
                end
            ),
            gleam@result:replace_error(_pipe@6, badarg)
        end
    ),
    gleam@result:replace(_pipe@7, nil).

-spec int_to_hex(integer()) -> binary().
int_to_hex(Int) ->
    erlang:integer_to_list(Int, 16).

-spec handle_chunked_body(
    gleam@http@response:response(response_data()),
    gleam@iterator:iterator(gleam@bytes_builder:bytes_builder()),
    mist@internal@http:connection()
) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
handle_chunked_body(Resp, Body, Conn) ->
    Headers = [{<<"transfer-encoding"/utf8>>, <<"chunked"/utf8>>} |
        erlang:element(3, Resp)],
    Initial_payload = mist@internal@encoder:response_builder(
        erlang:element(2, Resp),
        Headers
    ),
    _pipe = (erlang:element(12, erlang:element(4, Conn)))(
        erlang:element(3, Conn),
        Initial_payload
    ),
    _pipe@8 = gleam@result:then(_pipe, fun(_) -> _pipe@1 = Body,
            _pipe@2 = gleam@iterator:append(
                _pipe@1,
                gleam@iterator:from_list([gleam@bytes_builder:new()])
            ),
            gleam@iterator:try_fold(
                _pipe@2,
                nil,
                fun(_, Chunk) ->
                    Size = erlang:iolist_size(Chunk),
                    Encoded = begin
                        _pipe@3 = Size,
                        _pipe@4 = int_to_hex(_pipe@3),
                        _pipe@5 = gleam_stdlib:wrap_list(_pipe@4),
                        _pipe@6 = gleam@bytes_builder:append_string(
                            _pipe@5,
                            <<"\r\n"/utf8>>
                        ),
                        _pipe@7 = gleam_stdlib:iodata_append(_pipe@6, Chunk),
                        gleam@bytes_builder:append_string(
                            _pipe@7,
                            <<"\r\n"/utf8>>
                        )
                    end,
                    (erlang:element(12, erlang:element(4, Conn)))(
                        erlang:element(3, Conn),
                        Encoded
                    )
                end
            ) end),
    gleam@result:replace(_pipe@8, nil).

-spec close_or_set_timer(
    gleam@http@response:response(response_data()),
    mist@internal@http:connection(),
    gleam@erlang@process:subject(glisten@handler:message(KEF))
) -> gleam@otp@actor:next(glisten:message(KEF), state()).
close_or_set_timer(Resp, Conn, Sender) ->
    case gleam@http@response:get_header(Resp, <<"connection"/utf8>>) of
        {ok, <<"close"/utf8>>} ->
            _ = (erlang:element(4, erlang:element(4, Conn)))(
                erlang:element(3, Conn)
            ),
            {stop, normal};

        _ ->
            Timer = gleam@erlang@process:send_after(
                Sender,
                10000,
                {internal, close}
            ),
            gleam@otp@actor:continue({state, {some, Timer}})
    end.

-spec with_func(
    fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(response_data()))
) -> fun((glisten:message(KDX), state(), glisten:connection(KDX)) -> gleam@otp@actor:next(glisten:message(KDX), state())).
with_func(Handler) ->
    fun(Msg, State, Conn) ->
        {packet, Msg@1} = case Msg of
            {packet, _} -> Msg;
            _assert_fail ->
                erlang:error(#{gleam_error => let_assert,
                            message => <<"Assertion pattern match failed"/utf8>>,
                            value => _assert_fail,
                            module => <<"mist/internal/handler"/utf8>>,
                            function => <<"with_func"/utf8>>,
                            line => 52})
        end,
        Sender = erlang:element(5, Conn),
        Conn@1 = {connection,
            {initial, <<>>},
            erlang:element(3, Conn),
            erlang:element(4, Conn),
            erlang:element(2, Conn)},
        _pipe@16 = begin
            _ = case erlang:element(2, State) of
                {some, T} ->
                    gleam@erlang@process:cancel_timer(T);

                _ ->
                    timer_not_found
            end,
            _pipe = Msg@1,
            _pipe@1 = mist@internal@http:parse_request(_pipe, Conn@1),
            _pipe@2 = gleam@result:map_error(_pipe@1, fun(Err) -> case Err of
                        discard_packet ->
                            nil;

                        _ ->
                            mist@internal@logger:error(Err),
                            _ = (erlang:element(4, erlang:element(4, Conn@1)))(
                                erlang:element(3, Conn@1)
                            ),
                            nil
                    end end),
            _pipe@3 = gleam@result:replace_error(_pipe@2, {stop, normal}),
            _pipe@6 = gleam@result:then(
                _pipe@3,
                fun(Req) ->
                    _pipe@4 = gleam_erlang_ffi:rescue(fun() -> Handler(Req) end),
                    _pipe@5 = gleam@result:map(
                        _pipe@4,
                        fun(Resp) -> {Req, Resp} end
                    ),
                    gleam@result:map_error(
                        _pipe@5,
                        fun(_capture) ->
                            log_and_error(
                                _capture,
                                erlang:element(3, Conn@1),
                                erlang:element(4, Conn@1)
                            )
                        end
                    )
                end
            ),
            gleam@result:map(
                _pipe@6,
                fun(Req_resp) ->
                    {_, Response} = Req_resp,
                    case Response of
                        {response, _, _, {bytes, Body}} = Resp@1 ->
                            _pipe@7 = handle_bytes_builder_body(
                                Resp@1,
                                Body,
                                Conn@1
                            ),
                            _pipe@8 = gleam@result:map(
                                _pipe@7,
                                fun(_) ->
                                    close_or_set_timer(Resp@1, Conn@1, Sender)
                                end
                            ),
                            _pipe@9 = gleam@result:replace_error(
                                _pipe@8,
                                {stop, normal}
                            ),
                            gleam@result:unwrap_both(_pipe@9);

                        {response, _, _, {chunked, Body@1}} = Resp@2 ->
                            _pipe@10 = handle_chunked_body(
                                Resp@2,
                                Body@1,
                                Conn@1
                            ),
                            _pipe@11 = gleam@result:map(
                                _pipe@10,
                                fun(_) ->
                                    close_or_set_timer(Resp@2, Conn@1, Sender)
                                end
                            ),
                            _pipe@12 = gleam@result:replace_error(
                                _pipe@11,
                                {stop, normal}
                            ),
                            gleam@result:unwrap_both(_pipe@12);

                        {response, _, _, {file, _, _, _}} = Resp@3 ->
                            _pipe@13 = handle_file_body(Resp@3, Conn@1),
                            _pipe@14 = gleam@result:map(
                                _pipe@13,
                                fun(_) ->
                                    close_or_set_timer(Resp@3, Conn@1, Sender)
                                end
                            ),
                            _pipe@15 = gleam@result:replace_error(
                                _pipe@14,
                                {stop, normal}
                            ),
                            gleam@result:unwrap_both(_pipe@15);

                        {response, _, _, {websocket, Selector}} ->
                            _ = gleam_erlang_ffi:select(Selector),
                            {stop, normal}
                    end
                end
            )
        end,
        gleam@result:unwrap_both(_pipe@16)
    end.
