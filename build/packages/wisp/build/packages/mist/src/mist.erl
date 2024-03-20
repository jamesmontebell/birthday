-module(mist).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([send_file/3, read_body/2, stream/1, new/1, port/2, read_request_body/3, after_start/2, start_http/1, start_https/3, websocket/4, send_binary_frame/2, send_text_frame/2]).
-export_type([response_data/0, file_error/0, read_error/0, chunk/0, chunk_state/0, builder/2, websocket_message/1]).

-type response_data() :: {websocket,
        gleam@erlang@process:selector(gleam@erlang@process:process_down())} |
    {bytes, gleam@bytes_builder:bytes_builder()} |
    {chunked, gleam@iterator:iterator(gleam@bytes_builder:bytes_builder())} |
    {file, mist@internal@file:file_descriptor(), integer(), integer()}.

-type file_error() :: is_dir | no_access | no_entry | unknown_file_error.

-type read_error() :: excess_body | malformed_body.

-type chunk() :: {chunk,
        bitstring(),
        fun((integer()) -> {ok, chunk()} | {error, read_error()})} |
    done.

-type chunk_state() :: {chunk_state,
        mist@internal@buffer:buffer(),
        mist@internal@buffer:buffer(),
        boolean()}.

-opaque builder(KZC, KZD) :: {builder,
        integer(),
        fun((gleam@http@request:request(KZC)) -> gleam@http@response:response(KZD)),
        fun((integer(), gleam@http:scheme()) -> nil)}.

-type websocket_message(KZE) :: {text, binary()} |
    {binary, bitstring()} |
    closed |
    shutdown |
    {custom, KZE}.

-spec convert_file_errors(mist@internal@file:file_error()) -> file_error().
convert_file_errors(Err) ->
    case Err of
        is_dir ->
            is_dir;

        no_access ->
            no_access;

        no_entry ->
            no_entry;

        unknown_file_error ->
            unknown_file_error
    end.

-spec send_file(binary(), integer(), gleam@option:option(integer())) -> {ok,
        response_data()} |
    {error, file_error()}.
send_file(Path, Offset, Limit) ->
    _pipe = Path,
    _pipe@1 = gleam_stdlib:identity(_pipe),
    _pipe@2 = mist@internal@file:stat(_pipe@1),
    _pipe@3 = gleam@result:map_error(_pipe@2, fun convert_file_errors/1),
    gleam@result:map(
        _pipe@3,
        fun(Stat) ->
            {file,
                erlang:element(2, Stat),
                Offset,
                gleam@option:unwrap(Limit, erlang:element(3, Stat))}
        end
    ).

-spec read_body(
    gleam@http@request:request(mist@internal@http:connection()),
    integer()
) -> {ok, gleam@http@request:request(bitstring())} | {error, read_error()}.
read_body(Req, Max_body_limit) ->
    _pipe = Req,
    _pipe@1 = gleam@http@request:get_header(_pipe, <<"content-length"/utf8>>),
    _pipe@2 = gleam@result:then(_pipe@1, fun gleam@int:parse/1),
    _pipe@3 = gleam@result:unwrap(_pipe@2, 0),
    (fun(Content_length) -> case Content_length of
            Value when Value =< Max_body_limit ->
                _pipe@4 = mist@internal@http:read_body(Req),
                gleam@result:replace_error(_pipe@4, malformed_body);

            _ ->
                {error, excess_body}
        end end)(_pipe@3).

-spec do_stream(
    gleam@http@request:request(mist@internal@http:connection()),
    mist@internal@buffer:buffer()
) -> fun((integer()) -> {ok, chunk()} | {error, read_error()}).
do_stream(Req, Buffer) ->
    fun(Size) ->
        Socket = erlang:element(3, erlang:element(4, Req)),
        Transport = erlang:element(4, erlang:element(4, Req)),
        Byte_size = erlang:byte_size(erlang:element(3, Buffer)),
        case {erlang:element(2, Buffer), Byte_size} of
            {0, 0} ->
                {ok, done};

            {0, _} ->
                {Data, Rest} = mist@internal@buffer:slice(Buffer, Size),
                {ok,
                    {chunk,
                        Data,
                        do_stream(Req, mist@internal@buffer:new(Rest))}};

            {_, Buffer_size} when Buffer_size >= Size ->
                {Data@1, Rest@1} = mist@internal@buffer:slice(Buffer, Size),
                New_buffer = erlang:setelement(3, Buffer, Rest@1),
                {ok, {chunk, Data@1, do_stream(Req, New_buffer)}};

            {_, _} ->
                _pipe = mist@internal@http:read_data(
                    Socket,
                    Transport,
                    mist@internal@buffer:empty(),
                    invalid_body
                ),
                _pipe@1 = gleam@result:replace_error(_pipe, malformed_body),
                gleam@result:map(
                    _pipe@1,
                    fun(Data@2) ->
                        Fetched_data = erlang:byte_size(Data@2),
                        New_buffer@1 = {buffer,
                            gleam@int:max(
                                0,
                                erlang:element(2, Buffer) - Fetched_data
                            ),
                            gleam@bit_array:append(
                                erlang:element(3, Buffer),
                                Data@2
                            )},
                        {New_data, Rest@2} = mist@internal@buffer:slice(
                            New_buffer@1,
                            Size
                        ),
                        {chunk,
                            New_data,
                            do_stream(
                                Req,
                                erlang:setelement(3, New_buffer@1, Rest@2)
                            )}
                    end
                )
        end
    end.

-spec fetch_chunks_until(
    glisten@socket:socket(),
    glisten@socket@transport:transport(),
    chunk_state(),
    integer()
) -> {ok, {bitstring(), chunk_state()}} | {error, read_error()}.
fetch_chunks_until(Socket, Transport, State, Byte_size) ->
    Data_size = erlang:byte_size(erlang:element(3, erlang:element(2, State))),
    case {erlang:element(4, State), Data_size} of
        {_, Size} when Size >= Byte_size ->
            {Value, Rest} = mist@internal@buffer:slice(
                erlang:element(2, State),
                Byte_size
            ),
            {ok,
                {Value,
                    erlang:setelement(2, State, mist@internal@buffer:new(Rest))}};

        {true, _} ->
            {ok,
                {erlang:element(3, erlang:element(2, State)),
                    erlang:setelement(4, State, true)}};

        {false, _} ->
            case mist@internal@http:parse_chunk(
                erlang:element(3, erlang:element(3, State))
            ) of
                complete ->
                    Updated_state = erlang:setelement(
                        4,
                        erlang:setelement(
                            3,
                            State,
                            mist@internal@buffer:empty()
                        ),
                        true
                    ),
                    fetch_chunks_until(
                        Socket,
                        Transport,
                        Updated_state,
                        Byte_size
                    );

                {chunk, <<>>, Next_buffer} ->
                    _pipe = mist@internal@http:read_data(
                        Socket,
                        Transport,
                        Next_buffer,
                        invalid_body
                    ),
                    _pipe@1 = gleam@result:replace_error(_pipe, malformed_body),
                    gleam@result:then(
                        _pipe@1,
                        fun(New_data) ->
                            Updated_state@1 = erlang:setelement(
                                3,
                                State,
                                mist@internal@buffer:new(New_data)
                            ),
                            fetch_chunks_until(
                                Socket,
                                Transport,
                                Updated_state@1,
                                Byte_size
                            )
                        end
                    );

                {chunk, Data, Next_buffer@1} ->
                    Updated_state@2 = erlang:setelement(
                        3,
                        erlang:setelement(
                            2,
                            State,
                            mist@internal@buffer:append(
                                erlang:element(2, State),
                                Data
                            )
                        ),
                        Next_buffer@1
                    ),
                    fetch_chunks_until(
                        Socket,
                        Transport,
                        Updated_state@2,
                        Byte_size
                    )
            end
    end.

-spec do_stream_chunked(
    gleam@http@request:request(mist@internal@http:connection()),
    chunk_state()
) -> fun((integer()) -> {ok, chunk()} | {error, read_error()}).
do_stream_chunked(Req, State) ->
    Socket = erlang:element(3, erlang:element(4, Req)),
    Transport = erlang:element(4, erlang:element(4, Req)),
    fun(Size) -> case fetch_chunks_until(Socket, Transport, State, Size) of
            {ok, {Data, {chunk_state, _, _, true}}} ->
                {ok, {chunk, Data, fun(_) -> {ok, done} end}};

            {ok, {Data@1, State@1}} ->
                {ok, {chunk, Data@1, do_stream_chunked(Req, State@1)}};

            {error, _} ->
                {error, malformed_body}
        end end.

-spec stream(gleam@http@request:request(mist@internal@http:connection())) -> {ok,
        fun((integer()) -> {ok, chunk()} | {error, read_error()})} |
    {error, read_error()}.
stream(Req) ->
    Continue = begin
        _pipe = Req,
        _pipe@1 = mist@internal@http:handle_continue(_pipe),
        gleam@result:replace_error(_pipe@1, malformed_body)
    end,
    gleam@result:map(
        Continue,
        fun(_) ->
            Is_chunked = case gleam@http@request:get_header(
                Req,
                <<"transfer-encoding"/utf8>>
            ) of
                {ok, <<"chunked"/utf8>>} ->
                    true;

                _ ->
                    false
            end,
            _assert_subject = erlang:element(2, erlang:element(4, Req)),
            {initial, Data} = case _assert_subject of
                {initial, _} -> _assert_subject;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Assertion pattern match failed"/utf8>>,
                                value => _assert_fail,
                                module => <<"mist"/utf8>>,
                                function => <<"stream"/utf8>>,
                                line => 267})
            end,
            case Is_chunked of
                true ->
                    State = {chunk_state,
                        mist@internal@buffer:new(<<>>),
                        mist@internal@buffer:new(Data),
                        false},
                    do_stream_chunked(Req, State);

                false ->
                    Content_length = begin
                        _pipe@2 = Req,
                        _pipe@3 = gleam@http@request:get_header(
                            _pipe@2,
                            <<"content-length"/utf8>>
                        ),
                        _pipe@4 = gleam@result:then(
                            _pipe@3,
                            fun gleam@int:parse/1
                        ),
                        gleam@result:unwrap(_pipe@4, 0)
                    end,
                    Initial_size = erlang:byte_size(Data),
                    Buffer = {buffer,
                        gleam@int:max(0, Content_length - Initial_size),
                        Data},
                    do_stream(Req, Buffer)
            end
        end
    ).

-spec new(
    fun((gleam@http@request:request(KZZ)) -> gleam@http@response:response(LAB))
) -> builder(KZZ, LAB).
new(Handler) ->
    {builder,
        4000,
        Handler,
        fun(Port, Scheme) ->
            Message = <<<<<<"Listening on "/utf8,
                        (gleam@http:scheme_to_string(Scheme))/binary>>/binary,
                    "://localhost:"/utf8>>/binary,
                (gleam@int:to_string(Port))/binary>>,
            gleam@io:println(Message)
        end}.

-spec port(builder(LAF, LAG), integer()) -> builder(LAF, LAG).
port(Builder, Port) ->
    erlang:setelement(2, Builder, Port).

-spec read_request_body(
    builder(bitstring(), LAL),
    integer(),
    gleam@http@response:response(LAL)
) -> builder(mist@internal@http:connection(), LAL).
read_request_body(Builder, Bytes_limit, Failure_response) ->
    Handler = fun(Request) -> case read_body(Request, Bytes_limit) of
            {ok, Request@1} ->
                (erlang:element(3, Builder))(Request@1);

            {error, _} ->
                Failure_response
        end end,
    {builder, erlang:element(2, Builder), Handler, erlang:element(4, Builder)}.

-spec after_start(
    builder(LAR, LAS),
    fun((integer(), gleam@http:scheme()) -> nil)
) -> builder(LAR, LAS).
after_start(Builder, After_start) ->
    erlang:setelement(4, Builder, After_start).

-spec convert_body_types(gleam@http@response:response(response_data())) -> gleam@http@response:response(mist@internal@handler:response_data()).
convert_body_types(Resp) ->
    New_body = case erlang:element(4, Resp) of
        {websocket, Selector} ->
            {websocket, Selector};

        {bytes, Data} ->
            {bytes, Data};

        {file, Descriptor, Offset, Length} ->
            {file, Descriptor, Offset, Length};

        {chunked, Iter} ->
            {chunked, Iter}
    end,
    gleam@http@response:set_body(Resp, New_body).

-spec start_http(builder(mist@internal@http:connection(), response_data())) -> {ok,
        gleam@erlang@process:subject(gleam@otp@supervisor:message())} |
    {error, glisten:start_error()}.
start_http(Builder) ->
    _pipe = erlang:element(3, Builder),
    _pipe@1 = gleam@function:compose(_pipe, fun convert_body_types/1),
    _pipe@2 = mist@internal@handler:with_func(_pipe@1),
    _pipe@3 = glisten:handler(
        fun() -> {mist@internal@handler:new_state(), none} end,
        _pipe@2
    ),
    _pipe@4 = glisten:serve(_pipe@3, erlang:element(2, Builder)),
    gleam@result:map(
        _pipe@4,
        fun(Subj) ->
            (erlang:element(4, Builder))(erlang:element(2, Builder), http),
            Subj
        end
    ).

-spec start_https(
    builder(mist@internal@http:connection(), response_data()),
    binary(),
    binary()
) -> {ok, gleam@erlang@process:subject(gleam@otp@supervisor:message())} |
    {error, glisten:start_error()}.
start_https(Builder, Certfile, Keyfile) ->
    _pipe = erlang:element(3, Builder),
    _pipe@1 = gleam@function:compose(_pipe, fun convert_body_types/1),
    _pipe@2 = mist@internal@handler:with_func(_pipe@1),
    _pipe@3 = glisten:handler(
        fun() -> {mist@internal@handler:new_state(), none} end,
        _pipe@2
    ),
    _pipe@4 = glisten:serve_ssl(
        _pipe@3,
        erlang:element(2, Builder),
        Certfile,
        Keyfile
    ),
    gleam@result:map(
        _pipe@4,
        fun(Subj) ->
            (erlang:element(4, Builder))(erlang:element(2, Builder), https),
            Subj
        end
    ).

-spec internal_to_public_ws_message(
    mist@internal@websocket:handler_message(LBJ)
) -> {ok, websocket_message(LBJ)} | {error, nil}.
internal_to_public_ws_message(Msg) ->
    case Msg of
        {internal, {data, {text_frame, _, Data}}} ->
            _pipe = Data,
            _pipe@1 = gleam@bit_array:to_string(_pipe),
            gleam@result:map(_pipe@1, fun(Field@0) -> {text, Field@0} end);

        {internal, {data, {binary_frame, _, Data@1}}} ->
            {ok, {binary, Data@1}};

        {user, Msg@1} ->
            {ok, {custom, Msg@1}};

        _ ->
            {error, nil}
    end.

-spec websocket(
    gleam@http@request:request(mist@internal@http:connection()),
    fun((LBP, mist@internal@websocket:websocket_connection(), websocket_message(LBQ)) -> gleam@otp@actor:next(LBQ, LBP)),
    fun((mist@internal@websocket:websocket_connection()) -> {LBP,
        gleam@option:option(gleam@erlang@process:selector(LBQ))}),
    fun((LBP) -> nil)
) -> gleam@http@response:response(response_data()).
websocket(Request, Handler, On_init, On_close) ->
    Handler@1 = fun(State, Connection, Message) -> _pipe = Message,
        _pipe@1 = internal_to_public_ws_message(_pipe),
        _pipe@2 = gleam@result:map(
            _pipe@1,
            fun(_capture) -> Handler(State, Connection, _capture) end
        ),
        gleam@result:unwrap(_pipe@2, gleam@otp@actor:continue(State)) end,
    Socket = erlang:element(3, erlang:element(4, Request)),
    Transport = erlang:element(4, erlang:element(4, Request)),
    _pipe@3 = Request,
    _pipe@4 = mist@internal@http:upgrade(Socket, Transport, _pipe@3),
    _pipe@5 = gleam@result:then(
        _pipe@4,
        fun(_) ->
            mist@internal@websocket:initialize_connection(
                On_init,
                On_close,
                Handler@1,
                Socket,
                Transport
            )
        end
    ),
    _pipe@8 = gleam@result:map(
        _pipe@5,
        fun(Subj) ->
            Ws_process = gleam@erlang@process:subject_owner(Subj),
            Monitor = gleam@erlang@process:monitor_process(Ws_process),
            Selector = begin
                _pipe@6 = gleam_erlang_ffi:new_selector(),
                gleam@erlang@process:selecting_process_down(
                    _pipe@6,
                    Monitor,
                    fun gleam@function:identity/1
                )
            end,
            _pipe@7 = gleam@http@response:new(200),
            gleam@http@response:set_body(_pipe@7, {websocket, Selector})
        end
    ),
    gleam@result:lazy_unwrap(
        _pipe@8,
        fun() -> _pipe@9 = gleam@http@response:new(400),
            gleam@http@response:set_body(
                _pipe@9,
                {bytes, gleam@bytes_builder:new()}
            ) end
    ).

-spec send_binary_frame(
    mist@internal@websocket:websocket_connection(),
    bitstring()
) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
send_binary_frame(Connection, Frame) ->
    _pipe = Frame,
    _pipe@1 = mist@internal@websocket:to_binary_frame(_pipe),
    (erlang:element(12, erlang:element(3, Connection)))(
        erlang:element(2, Connection),
        _pipe@1
    ).

-spec send_text_frame(mist@internal@websocket:websocket_connection(), binary()) -> {ok,
        nil} |
    {error, glisten@socket:socket_reason()}.
send_text_frame(Connection, Frame) ->
    _pipe = Frame,
    _pipe@1 = mist@internal@websocket:to_text_frame(_pipe),
    (erlang:element(12, erlang:element(3, Connection)))(
        erlang:element(2, Connection),
        _pipe@1
    ).
