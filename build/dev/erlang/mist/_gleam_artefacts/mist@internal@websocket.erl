-module(mist@internal@websocket).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([frame_to_bytes_builder/1, to_text_frame/1, to_binary_frame/1, aggregate_frames/3, initialize_connection/5]).
-export_type([data_frame/0, control_frame/0, frame/0, frame_parse_error/0, parsed_frame/0, valid_message/1, websocket_message/1, websocket_connection/0, handler_message/1, websocket_state/1]).

-type data_frame() :: {text_frame, integer(), bitstring()} |
    {binary_frame, integer(), bitstring()}.

-type control_frame() :: {close_frame, integer(), bitstring()} |
    {ping_frame, integer(), bitstring()} |
    {pong_frame, integer(), bitstring()}.

-type frame() :: {data, data_frame()} |
    {control, control_frame()} |
    {continuation, integer(), bitstring()}.

-type frame_parse_error() :: {need_more_data, bitstring()} | invalid_frame.

-type parsed_frame() :: {complete, frame()} | {incomplete, frame()}.

-type valid_message(EUP) :: {socket_message, bitstring()} |
    socket_closed_message |
    {user_message, EUP}.

-type websocket_message(EUQ) :: {valid, valid_message(EUQ)} | invalid.

-type websocket_connection() :: {websocket_connection,
        glisten@socket:socket(),
        glisten@socket@transport:transport()}.

-type handler_message(EUR) :: {internal, frame()} | {user, EUR}.

-type websocket_state(EUS) :: {websocket_state, bitstring(), EUS}.

-spec unmask_data(bitstring(), list(bitstring()), integer(), bitstring()) -> bitstring().
unmask_data(Data, Masks, Index, Resp) ->
    case Data of
        <<Masked:8/bitstring, Rest/bitstring>> ->
            _assert_subject = gleam@list:at(Masks, Index rem 4),
            {ok, Mask_value} = case _assert_subject of
                {ok, _} -> _assert_subject;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Assertion pattern match failed"/utf8>>,
                                value => _assert_fail,
                                module => <<"mist/internal/websocket"/utf8>>,
                                function => <<"unmask_data"/utf8>>,
                                line => 47})
            end,
            Unmasked = crypto:exor(Mask_value, Masked),
            unmask_data(
                Rest,
                Masks,
                Index + 1,
                <<Resp/bitstring, Unmasked/bitstring>>
            );

        _ ->
            Resp
    end.

-spec frame_from_message(bitstring(), websocket_connection()) -> {ok,
        {parsed_frame(), bitstring()}} |
    {error, frame_parse_error()}.
frame_from_message(Message, Conn) ->
    case Message of
        <<Complete:1,
            _:3,
            Opcode:4/integer,
            1:1,
            Payload_length:7/integer,
            Rest/bitstring>> ->
            Payload_size = case Payload_length of
                126 ->
                    16;

                127 ->
                    64;

                _ ->
                    0
            end,
            case Rest of
                <<Length:Payload_size/integer,
                    Mask1:1/binary,
                    Mask2:1/binary,
                    Mask3:1/binary,
                    Mask4:1/binary,
                    Rest@1/bitstring>> ->
                    Payload_byte_size = case Length of
                        0 ->
                            Payload_length;

                        N ->
                            N
                    end,
                    case Rest@1 of
                        <<Payload:Payload_byte_size/binary, Rest@2/bitstring>> ->
                            Data = unmask_data(
                                Payload,
                                [Mask1, Mask2, Mask3, Mask4],
                                0,
                                <<>>
                            ),
                            _pipe = case Opcode of
                                0 ->
                                    {ok, {continuation, Payload_length, Data}};

                                1 ->
                                    {ok,
                                        {data,
                                            {text_frame, Payload_length, Data}}};

                                2 ->
                                    {ok,
                                        {data,
                                            {binary_frame, Payload_length, Data}}};

                                8 ->
                                    {ok,
                                        {control,
                                            {close_frame, Payload_length, Data}}};

                                9 ->
                                    {ok,
                                        {control,
                                            {ping_frame, Payload_length, Data}}};

                                10 ->
                                    {ok,
                                        {control,
                                            {pong_frame, Payload_length, Data}}};

                                _ ->
                                    {error, invalid_frame}
                            end,
                            gleam@result:then(
                                _pipe,
                                fun(Frame) -> case Complete of
                                        1 ->
                                            {ok, {{complete, Frame}, Rest@2}};

                                        0 ->
                                            {ok, {{incomplete, Frame}, Rest@2}};

                                        _ ->
                                            {error, invalid_frame}
                                    end end
                            );

                        _ ->
                            _assert_subject = (erlang:element(
                                10,
                                erlang:element(3, Conn)
                            ))(erlang:element(2, Conn), 0),
                            {ok, Data@1} = case _assert_subject of
                                {ok, _} -> _assert_subject;
                                _assert_fail ->
                                    erlang:error(#{gleam_error => let_assert,
                                                message => <<"Assertion pattern match failed"/utf8>>,
                                                value => _assert_fail,
                                                module => <<"mist/internal/websocket"/utf8>>,
                                                function => <<"frame_from_message"/utf8>>,
                                                line => 118})
                            end,
                            frame_from_message(
                                <<Message/bitstring, Data@1/bitstring>>,
                                Conn
                            )
                    end;

                _ ->
                    {error, invalid_frame}
            end;

        _ ->
            {error, invalid_frame}
    end.

-spec make_frame(integer(), integer(), bitstring()) -> gleam@bytes_builder:bytes_builder().
make_frame(Opcode, Length, Payload) ->
    Length_section = case Length of
        Length@1 when Length@1 > 65535 ->
            <<127:7, Length@1:64/integer>>;

        Length@2 when Length@2 >= 126 ->
            <<126:7, Length@2:16/integer>>;

        _ ->
            <<Length:7>>
    end,
    _pipe = <<1:1,
        0:3,
        Opcode:4,
        0:1,
        Length_section/bitstring,
        Payload/bitstring>>,
    gleam_stdlib:wrap_list(_pipe).

-spec frame_to_bytes_builder(frame()) -> gleam@bytes_builder:bytes_builder().
frame_to_bytes_builder(Frame) ->
    case Frame of
        {data, {text_frame, Payload_length, Payload}} ->
            make_frame(1, Payload_length, Payload);

        {control, {close_frame, Payload_length@1, Payload@1}} ->
            make_frame(8, Payload_length@1, Payload@1);

        {data, {binary_frame, Payload_length@2, Payload@2}} ->
            make_frame(2, Payload_length@2, Payload@2);

        {control, {pong_frame, Payload_length@3, Payload@3}} ->
            make_frame(10, Payload_length@3, Payload@3);

        {control, {ping_frame, Payload_length@4, Payload@4}} ->
            make_frame(9, Payload_length@4, Payload@4);

        {continuation, Length, Payload@5} ->
            make_frame(0, Length, Payload@5)
    end.

-spec to_text_frame(binary()) -> gleam@bytes_builder:bytes_builder().
to_text_frame(Data) ->
    Msg = gleam_stdlib:identity(Data),
    Size = erlang:byte_size(Msg),
    frame_to_bytes_builder({data, {text_frame, Size, Msg}}).

-spec to_binary_frame(bitstring()) -> gleam@bytes_builder:bytes_builder().
to_binary_frame(Data) ->
    Size = erlang:byte_size(Data),
    frame_to_bytes_builder({data, {binary_frame, Size, Data}}).

-spec message_selector() -> gleam@erlang@process:selector(websocket_message(any())).
message_selector() ->
    _pipe = gleam_erlang_ffi:new_selector(),
    _pipe@6 = gleam@erlang@process:selecting_record3(
        _pipe,
        erlang:binary_to_atom(<<"tcp"/utf8>>),
        fun(_, Data) -> _pipe@1 = Data,
            _pipe@2 = gleam@dynamic:bit_array(_pipe@1),
            _pipe@3 = gleam@result:replace_error(_pipe@2, nil),
            _pipe@4 = gleam@result:map(
                _pipe@3,
                fun(Field@0) -> {socket_message, Field@0} end
            ),
            _pipe@5 = gleam@result:map(
                _pipe@4,
                fun(Field@0) -> {valid, Field@0} end
            ),
            gleam@result:unwrap(_pipe@5, invalid) end
    ),
    _pipe@12 = gleam@erlang@process:selecting_record3(
        _pipe@6,
        erlang:binary_to_atom(<<"ssl"/utf8>>),
        fun(_, Data@1) -> _pipe@7 = Data@1,
            _pipe@8 = gleam@dynamic:bit_array(_pipe@7),
            _pipe@9 = gleam@result:replace_error(_pipe@8, nil),
            _pipe@10 = gleam@result:map(
                _pipe@9,
                fun(Field@0) -> {socket_message, Field@0} end
            ),
            _pipe@11 = gleam@result:map(
                _pipe@10,
                fun(Field@0) -> {valid, Field@0} end
            ),
            gleam@result:unwrap(_pipe@11, invalid) end
    ),
    _pipe@13 = gleam@erlang@process:selecting_record2(
        _pipe@12,
        erlang:binary_to_atom(<<"ssl_closed"/utf8>>),
        fun(_) -> {valid, socket_closed_message} end
    ),
    gleam@erlang@process:selecting_record2(
        _pipe@13,
        erlang:binary_to_atom(<<"tcp_closed"/utf8>>),
        fun(_) -> {valid, socket_closed_message} end
    ).

-spec get_messages(bitstring(), websocket_connection(), list(parsed_frame())) -> {list(parsed_frame()),
    bitstring()}.
get_messages(Data, Conn, Frames) ->
    case frame_from_message(Data, Conn) of
        {ok, {Frame, <<>>}} ->
            {gleam@list:reverse([Frame | Frames]), <<>>};

        {ok, {Frame@1, Rest}} ->
            get_messages(Rest, Conn, [Frame@1 | Frames]);

        {error, {need_more_data, Rest@1}} ->
            {Frames, Rest@1};

        {error, invalid_frame} ->
            {Frames, Data}
    end.

-spec set_active(websocket_connection()) -> nil.
set_active(Connection) ->
    _assert_subject = (erlang:element(13, erlang:element(3, Connection)))(
        erlang:element(2, Connection),
        [{active_mode, once}]
    ),
    {ok, _} = case _assert_subject of
        {ok, _} -> _assert_subject;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Assertion pattern match failed"/utf8>>,
                        value => _assert_fail,
                        module => <<"mist/internal/websocket"/utf8>>,
                        function => <<"set_active"/utf8>>,
                        line => 449})
    end,
    nil.

-spec map_user_selector(gleam@option:option(gleam@erlang@process:selector(EWH))) -> gleam@option:option(gleam@erlang@process:selector(websocket_message(EWH))).
map_user_selector(Selector) ->
    gleam@option:map(
        Selector,
        fun(_capture) ->
            gleam_erlang_ffi:map_selector(
                _capture,
                fun(Msg) -> {valid, {user_message, Msg}} end
            )
        end
    ).

-spec apply_frames(
    list(frame()),
    fun((EVR, websocket_connection(), handler_message(EVS)) -> gleam@otp@actor:next(EVS, EVR)),
    websocket_connection(),
    gleam@otp@actor:next(websocket_message(EVS), EVR),
    fun((EVR) -> nil)
) -> gleam@otp@actor:next(websocket_message(EVS), EVR).
apply_frames(Frames, Handler, Connection, Next, On_close) ->
    case {Frames, Next} of
        {_, {stop, Reason}} ->
            {stop, Reason};

        {[], Next@1} ->
            set_active(Connection),
            Next@1;

        {[{control, {close_frame, _, _}} = Frame | _], {continue, State, _}} ->
            _ = (erlang:element(12, erlang:element(3, Connection)))(
                erlang:element(2, Connection),
                frame_to_bytes_builder(Frame)
            ),
            On_close(State),
            {stop, normal};

        {[{control, {ping_frame, Length, Payload}} | _], {continue, State@1, _}} ->
            _pipe = (erlang:element(12, erlang:element(3, Connection)))(
                erlang:element(2, Connection),
                frame_to_bytes_builder({control, {pong_frame, Length, Payload}})
            ),
            _pipe@1 = gleam@result:map(
                _pipe,
                fun(_) ->
                    set_active(Connection),
                    gleam@otp@actor:continue(State@1)
                end
            ),
            gleam@result:lazy_unwrap(
                _pipe@1,
                fun() ->
                    On_close(State@1),
                    {stop, {abnormal, <<"Failed to send pong frame"/utf8>>}}
                end
            );

        {[Frame@1 | Rest], {continue, State@2, Prev_selector}} ->
            case gleam_erlang_ffi:rescue(
                fun() -> Handler(State@2, Connection, {internal, Frame@1}) end
            ) of
                {ok, {continue, State@3, Selector}} ->
                    Next_selector = begin
                        _pipe@2 = Selector,
                        _pipe@3 = map_user_selector(_pipe@2),
                        _pipe@4 = gleam@option:'or'(_pipe@3, Prev_selector),
                        gleam@option:map(
                            _pipe@4,
                            fun(With_user) ->
                                gleam_erlang_ffi:merge_selector(
                                    message_selector(),
                                    With_user
                                )
                            end
                        )
                    end,
                    apply_frames(
                        Rest,
                        Handler,
                        Connection,
                        {continue, State@3, Next_selector},
                        On_close
                    );

                {ok, {stop, Reason@1}} ->
                    On_close(State@2),
                    {stop, Reason@1};

                {error, Reason@2} ->
                    mist@internal@logger:error(
                        <<"Caught error in websocket handler: "/utf8,
                            (gleam@erlang:format(Reason@2))/binary>>
                    ),
                    On_close(State@2),
                    {stop,
                        {abnormal, <<"Crash in user websocket handler"/utf8>>}}
            end
    end.

-spec append_frame(frame(), integer(), bitstring()) -> frame().
append_frame(Left, Length, Data) ->
    case Left of
        {data, {text_frame, Len, Payload}} ->
            {data,
                {text_frame,
                    Len + Length,
                    <<Payload/bitstring, Data/bitstring>>}};

        {data, {binary_frame, Len@1, Payload@1}} ->
            {data,
                {binary_frame,
                    Len@1 + Length,
                    <<Payload@1/bitstring, Data/bitstring>>}};

        {control, {close_frame, Len@2, Payload@2}} ->
            {control,
                {close_frame,
                    Len@2 + Length,
                    <<Payload@2/bitstring, Data/bitstring>>}};

        {control, {ping_frame, Len@3, Payload@3}} ->
            {control,
                {ping_frame,
                    Len@3 + Length,
                    <<Payload@3/bitstring, Data/bitstring>>}};

        {control, {pong_frame, Len@4, Payload@4}} ->
            {control,
                {pong_frame,
                    Len@4 + Length,
                    <<Payload@4/bitstring, Data/bitstring>>}};

        {continuation, _, _} ->
            Left
    end.

-spec aggregate_frames(
    list(parsed_frame()),
    gleam@option:option(frame()),
    list(frame())
) -> {ok, list(frame())} | {error, nil}.
aggregate_frames(Frames, Previous, Joined) ->
    case {Frames, Previous} of
        {[], _} ->
            {ok, gleam@list:reverse(Joined)};

        {[{complete, {continuation, Length, Data}} | Rest], {some, Prev}} ->
            Next = append_frame(Prev, Length, Data),
            aggregate_frames(Rest, none, [Next | Joined]);

        {[{incomplete, {continuation, Length@1, Data@1}} | Rest@1],
            {some, Prev@1}} ->
            Next@1 = append_frame(Prev@1, Length@1, Data@1),
            aggregate_frames(Rest@1, {some, Next@1}, Joined);

        {[{incomplete, Frame} | Rest@2], none} ->
            aggregate_frames(Rest@2, {some, Frame}, Joined);

        {[{complete, Frame@1} | Rest@3], none} ->
            aggregate_frames(Rest@3, none, [Frame@1 | Joined]);

        {_, _} ->
            {error, nil}
    end.

-spec initialize_connection(
    fun((websocket_connection()) -> {EVE,
        gleam@option:option(gleam@erlang@process:selector(EVF))}),
    fun((EVE) -> nil),
    fun((EVE, websocket_connection(), handler_message(EVF)) -> gleam@otp@actor:next(EVF, EVE)),
    glisten@socket:socket(),
    glisten@socket@transport:transport()
) -> {ok, gleam@erlang@process:subject(websocket_message(EVF))} | {error, nil}.
initialize_connection(On_init, On_close, Handler, Socket, Transport) ->
    Connection = {websocket_connection, Socket, Transport},
    _pipe@11 = gleam@otp@actor:start_spec(
        {spec,
            fun() ->
                {Initial_state, User_selector} = On_init(Connection),
                Selector = case User_selector of
                    {some, User_selector@1} ->
                        _pipe = User_selector@1,
                        _pipe@1 = gleam_erlang_ffi:map_selector(
                            _pipe,
                            fun(Field@0) -> {user_message, Field@0} end
                        ),
                        _pipe@2 = gleam_erlang_ffi:map_selector(
                            _pipe@1,
                            fun(Field@0) -> {valid, Field@0} end
                        ),
                        gleam_erlang_ffi:merge_selector(
                            _pipe@2,
                            message_selector()
                        );

                    _ ->
                        message_selector()
                end,
                {ready, {websocket_state, <<>>, Initial_state}, Selector}
            end,
            500,
            fun(Msg, State) -> case Msg of
                    {valid, {socket_message, Data}} ->
                        {Frames, Rest} = get_messages(
                            <<(erlang:element(2, State))/bitstring,
                                Data/bitstring>>,
                            Connection,
                            []
                        ),
                        _pipe@3 = Frames,
                        _pipe@4 = aggregate_frames(_pipe@3, none, []),
                        _pipe@5 = gleam@result:map(
                            _pipe@4,
                            fun(Frames@1) ->
                                Next = apply_frames(
                                    Frames@1,
                                    Handler,
                                    Connection,
                                    gleam@otp@actor:continue(
                                        erlang:element(3, State)
                                    ),
                                    On_close
                                ),
                                case Next of
                                    {continue, User_state, Selector@1} ->
                                        {continue,
                                            {websocket_state, Rest, User_state},
                                            Selector@1};

                                    {stop, Reason} ->
                                        {stop, Reason}
                                end
                            end
                        ),
                        gleam@result:lazy_unwrap(
                            _pipe@5,
                            fun() ->
                                mist@internal@logger:error(
                                    {<<"Received a malformed WebSocket frame"/utf8>>}
                                ),
                                On_close(erlang:element(3, State)),
                                {stop,
                                    {abnormal,
                                        <<"WebSocket received a malformed message"/utf8>>}}
                            end
                        );

                    {valid, {user_message, Msg@1}} ->
                        _pipe@6 = gleam_erlang_ffi:rescue(
                            fun() ->
                                Handler(
                                    erlang:element(3, State),
                                    Connection,
                                    {user, Msg@1}
                                )
                            end
                        ),
                        _pipe@9 = gleam@result:map(
                            _pipe@6,
                            fun(Cont) -> case Cont of
                                    {continue, User_state@1, Selector@2} ->
                                        Selector@3 = begin
                                            _pipe@7 = Selector@2,
                                            _pipe@8 = map_user_selector(_pipe@7),
                                            gleam@option:map(
                                                _pipe@8,
                                                fun(With_user) ->
                                                    gleam_erlang_ffi:merge_selector(
                                                        message_selector(),
                                                        With_user
                                                    )
                                                end
                                            )
                                        end,
                                        {continue,
                                            erlang:setelement(
                                                3,
                                                State,
                                                User_state@1
                                            ),
                                            Selector@3};

                                    {stop, Reason@1} ->
                                        On_close(erlang:element(3, State)),
                                        {stop, Reason@1}
                                end end
                        ),
                        _pipe@10 = gleam@result:map_error(
                            _pipe@9,
                            fun(Err) ->
                                mist@internal@logger:error(
                                    <<"Caught error in websocket handler: "/utf8,
                                        (gleam@erlang:format(Err))/binary>>
                                )
                            end
                        ),
                        gleam@result:lazy_unwrap(
                            _pipe@10,
                            fun() ->
                                On_close(erlang:element(3, State)),
                                {stop,
                                    {abnormal,
                                        <<"Crash in user websocket handler"/utf8>>}}
                            end
                        );

                    {valid, socket_closed_message} ->
                        On_close(erlang:element(3, State)),
                        {stop, normal};

                    invalid ->
                        mist@internal@logger:error(
                            {<<"Received a malformed WebSocket frame"/utf8>>}
                        ),
                        On_close(erlang:element(3, State)),
                        {stop,
                            {abnormal,
                                <<"WebSocket received a malformed message"/utf8>>}}
                end end}
    ),
    _pipe@12 = gleam@result:replace_error(_pipe@11, nil),
    _pipe@13 = gleam@result:map(
        _pipe@12,
        fun(Subj) ->
            Websocket_pid = gleam@erlang@process:subject_owner(Subj),
            _assert_subject = (erlang:element(5, erlang:element(3, Connection)))(
                erlang:element(2, Connection),
                Websocket_pid
            ),
            {ok, _} = case _assert_subject of
                {ok, _} -> _assert_subject;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Assertion pattern match failed"/utf8>>,
                                value => _assert_fail,
                                module => <<"mist/internal/websocket"/utf8>>,
                                function => <<"initialize_connection"/utf8>>,
                                line => 331})
            end,
            set_active(Connection),
            Subj
        end
    ),
    gleam@result:replace_error(_pipe@13, nil).
