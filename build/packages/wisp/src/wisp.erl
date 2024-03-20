-module(wisp).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([response/1, set_body/2, html_response/2, json_response/2, html_body/2, json_body/2, string_builder_body/2, string_body/2, escape_html/1, method_not_allowed/1, ok/0, created/0, accepted/0, redirect/1, moved_permanently/1, no_content/0, not_found/0, bad_request/0, entity_too_large/0, unsupported_media_type/1, unprocessable_entity/0, internal_server_error/0, set_max_body_size/2, get_max_body_size/1, set_secret_key_base/2, get_secret_key_base/1, set_max_files_size/2, get_max_files_size/1, set_read_chunk_size/2, get_read_chunk_size/1, require_method/3, get_query/1, method_override/1, read_body_to_bitstring/1, require_bit_array_body/2, require_content_type/3, require_string_body/2, require_json/2, serve_static/4, handle_head/2, delete_temporary_files/1, configure_logger/0, log_emergency/1, log_alert/1, log_critical/1, log_error/1, rescue_crashes/1, log_warning/1, log_notice/1, log_info/1, log_request/2, log_debug/1, random_string/1, sign_message/3, verify_signed_message/2, mist_handler/2, new_temporary_file/1, require_form/2, set_cookie/6, get_cookie/3, create_canned_connection/2]).
-export_type([body/0, connection/0, buffered_reader/0, quotas/0, read/0, form_data/0, uploaded_file/0, do_not_leak/0, error_kind/0, security/0]).

-type body() :: {text, gleam@string_builder:string_builder()} |
    {file, binary()} |
    empty.

-opaque connection() :: {connection,
        fun((integer()) -> {ok, read()} | {error, nil}),
        integer(),
        integer(),
        integer(),
        binary(),
        binary()}.

-type buffered_reader() :: {buffered_reader,
        fun((integer()) -> {ok, read()} | {error, nil}),
        bitstring()}.

-type quotas() :: {quotas, integer(), integer()}.

-type read() :: {chunk,
        bitstring(),
        fun((integer()) -> {ok, read()} | {error, nil})} |
    reading_finished.

-type form_data() :: {form_data,
        list({binary(), binary()}),
        list({binary(), uploaded_file()})}.

-type uploaded_file() :: {uploaded_file, binary(), binary()}.

-type do_not_leak() :: any().

-type error_kind() :: errored | thrown | exited.

-type security() :: plain_text | signed.

-spec wrap_mist_chunk({ok, mist:chunk()} | {error, mist:read_error()}) -> {ok,
        read()} |
    {error, nil}.
wrap_mist_chunk(Chunk) ->
    _pipe = Chunk,
    _pipe@1 = gleam@result:nil_error(_pipe),
    gleam@result:map(_pipe@1, fun(Chunk@1) -> case Chunk@1 of
                done ->
                    reading_finished;

                {chunk, Data, Consume} ->
                    {chunk,
                        Data,
                        fun(Size) -> wrap_mist_chunk(Consume(Size)) end}
            end end).

-spec mist_body_reader(
    gleam@http@request:request(mist@internal@http:connection())
) -> fun((integer()) -> {ok, read()} | {error, nil}).
mist_body_reader(Request) ->
    case mist:stream(Request) of
        {error, _} ->
            fun(_) -> {ok, reading_finished} end;

        {ok, Stream} ->
            fun(Size) -> wrap_mist_chunk(Stream(Size)) end
    end.

-spec response(integer()) -> gleam@http@response:response(body()).
response(Status) ->
    {response, Status, [], empty}.

-spec set_body(gleam@http@response:response(body()), body()) -> gleam@http@response:response(body()).
set_body(Response, Body) ->
    _pipe = Response,
    gleam@http@response:set_body(_pipe, Body).

-spec html_response(gleam@string_builder:string_builder(), integer()) -> gleam@http@response:response(body()).
html_response(Html, Status) ->
    {response,
        Status,
        [{<<"content-type"/utf8>>, <<"text/html"/utf8>>}],
        {text, Html}}.

-spec json_response(gleam@string_builder:string_builder(), integer()) -> gleam@http@response:response(body()).
json_response(Json, Status) ->
    {response,
        Status,
        [{<<"content-type"/utf8>>, <<"application/json"/utf8>>}],
        {text, Json}}.

-spec html_body(
    gleam@http@response:response(body()),
    gleam@string_builder:string_builder()
) -> gleam@http@response:response(body()).
html_body(Response, Html) ->
    _pipe = Response,
    _pipe@1 = gleam@http@response:set_body(_pipe, {text, Html}),
    gleam@http@response:set_header(
        _pipe@1,
        <<"content-type"/utf8>>,
        <<"text/html"/utf8>>
    ).

-spec json_body(
    gleam@http@response:response(body()),
    gleam@string_builder:string_builder()
) -> gleam@http@response:response(body()).
json_body(Response, Json) ->
    _pipe = Response,
    _pipe@1 = gleam@http@response:set_body(_pipe, {text, Json}),
    gleam@http@response:set_header(
        _pipe@1,
        <<"content-type"/utf8>>,
        <<"application/json"/utf8>>
    ).

-spec string_builder_body(
    gleam@http@response:response(body()),
    gleam@string_builder:string_builder()
) -> gleam@http@response:response(body()).
string_builder_body(Response, Content) ->
    _pipe = Response,
    gleam@http@response:set_body(_pipe, {text, Content}).

-spec string_body(gleam@http@response:response(body()), binary()) -> gleam@http@response:response(body()).
string_body(Response, Content) ->
    _pipe = Response,
    gleam@http@response:set_body(
        _pipe,
        {text, gleam@string_builder:from_string(Content)}
    ).

-spec do_escape_html(binary(), binary()) -> binary().
do_escape_html(Escaped, Content) ->
    case gleam@string:pop_grapheme(Content) of
        {ok, {<<"<"/utf8>>, Xs}} ->
            do_escape_html(<<Escaped/binary, "&lt;"/utf8>>, Xs);

        {ok, {<<">"/utf8>>, Xs@1}} ->
            do_escape_html(<<Escaped/binary, "&gt;"/utf8>>, Xs@1);

        {ok, {<<"&"/utf8>>, Xs@2}} ->
            do_escape_html(<<Escaped/binary, "&amp;"/utf8>>, Xs@2);

        {ok, {X, Xs@3}} ->
            do_escape_html(<<Escaped/binary, X/binary>>, Xs@3);

        {error, _} ->
            <<Escaped/binary, Content/binary>>
    end.

-spec escape_html(binary()) -> binary().
escape_html(Content) ->
    do_escape_html(<<""/utf8>>, Content).

-spec method_not_allowed(list(gleam@http:method())) -> gleam@http@response:response(body()).
method_not_allowed(Methods) ->
    Allowed = begin
        _pipe = Methods,
        _pipe@1 = gleam@list:map(_pipe, fun gleam@http:method_to_string/1),
        _pipe@2 = gleam@list:sort(_pipe@1, fun gleam@string:compare/2),
        _pipe@3 = gleam@string:join(_pipe@2, <<", "/utf8>>),
        gleam@string:uppercase(_pipe@3)
    end,
    {response, 405, [{<<"allow"/utf8>>, Allowed}], empty}.

-spec ok() -> gleam@http@response:response(body()).
ok() ->
    {response, 200, [], empty}.

-spec created() -> gleam@http@response:response(body()).
created() ->
    {response, 201, [], empty}.

-spec accepted() -> gleam@http@response:response(body()).
accepted() ->
    {response, 202, [], empty}.

-spec redirect(binary()) -> gleam@http@response:response(body()).
redirect(Url) ->
    {response, 303, [{<<"location"/utf8>>, Url}], empty}.

-spec moved_permanently(binary()) -> gleam@http@response:response(body()).
moved_permanently(Url) ->
    {response, 308, [{<<"location"/utf8>>, Url}], empty}.

-spec no_content() -> gleam@http@response:response(body()).
no_content() ->
    {response, 204, [], empty}.

-spec not_found() -> gleam@http@response:response(body()).
not_found() ->
    {response, 404, [], empty}.

-spec bad_request() -> gleam@http@response:response(body()).
bad_request() ->
    {response, 400, [], empty}.

-spec entity_too_large() -> gleam@http@response:response(body()).
entity_too_large() ->
    {response, 413, [], empty}.

-spec unsupported_media_type(list(binary())) -> gleam@http@response:response(body()).
unsupported_media_type(Acceptable) ->
    Acceptable@1 = gleam@string:join(Acceptable, <<", "/utf8>>),
    {response, 415, [{<<"accept"/utf8>>, Acceptable@1}], empty}.

-spec unprocessable_entity() -> gleam@http@response:response(body()).
unprocessable_entity() ->
    {response, 422, [], empty}.

-spec internal_server_error() -> gleam@http@response:response(body()).
internal_server_error() ->
    {response, 500, [], empty}.

-spec decrement_body_quota(quotas(), integer()) -> {ok, quotas()} |
    {error, gleam@http@response:response(body())}.
decrement_body_quota(Quotas, Size) ->
    Quotas@1 = erlang:setelement(2, Quotas, erlang:element(2, Quotas) - Size),
    case erlang:element(2, Quotas@1) < 0 of
        true ->
            {error, entity_too_large()};

        false ->
            {ok, Quotas@1}
    end.

-spec decrement_quota(integer(), integer()) -> {ok, integer()} |
    {error, gleam@http@response:response(body())}.
decrement_quota(Quota, Size) ->
    case Quota - Size of
        Quota@1 when Quota@1 < 0 ->
            {error, entity_too_large()};

        Quota@2 ->
            {ok, Quota@2}
    end.

-spec buffered_read(buffered_reader(), integer()) -> {ok, read()} | {error, nil}.
buffered_read(Reader, Chunk_size) ->
    case erlang:element(3, Reader) of
        <<>> ->
            (erlang:element(2, Reader))(Chunk_size);

        _ ->
            {ok, {chunk, erlang:element(3, Reader), erlang:element(2, Reader)}}
    end.

-spec set_max_body_size(gleam@http@request:request(connection()), integer()) -> gleam@http@request:request(connection()).
set_max_body_size(Request, Size) ->
    _pipe = erlang:setelement(3, erlang:element(4, Request), Size),
    gleam@http@request:set_body(Request, _pipe).

-spec get_max_body_size(gleam@http@request:request(connection())) -> integer().
get_max_body_size(Request) ->
    erlang:element(3, erlang:element(4, Request)).

-spec set_secret_key_base(gleam@http@request:request(connection()), binary()) -> gleam@http@request:request(connection()).
set_secret_key_base(Request, Key) ->
    case erlang:byte_size(Key) < 64 of
        true ->
            erlang:error(#{gleam_error => panic,
                    message => <<"Secret key base must be at least 64 bytes long"/utf8>>,
                    module => <<"wisp"/utf8>>,
                    function => <<"set_secret_key_base"/utf8>>,
                    line => 614});

        false ->
            _pipe = erlang:setelement(6, erlang:element(4, Request), Key),
            gleam@http@request:set_body(Request, _pipe)
    end.

-spec get_secret_key_base(gleam@http@request:request(connection())) -> binary().
get_secret_key_base(Request) ->
    erlang:element(6, erlang:element(4, Request)).

-spec set_max_files_size(gleam@http@request:request(connection()), integer()) -> gleam@http@request:request(connection()).
set_max_files_size(Request, Size) ->
    _pipe = erlang:setelement(4, erlang:element(4, Request), Size),
    gleam@http@request:set_body(Request, _pipe).

-spec get_max_files_size(gleam@http@request:request(connection())) -> integer().
get_max_files_size(Request) ->
    erlang:element(4, erlang:element(4, Request)).

-spec set_read_chunk_size(gleam@http@request:request(connection()), integer()) -> gleam@http@request:request(connection()).
set_read_chunk_size(Request, Size) ->
    _pipe = erlang:setelement(5, erlang:element(4, Request), Size),
    gleam@http@request:set_body(Request, _pipe).

-spec get_read_chunk_size(gleam@http@request:request(connection())) -> integer().
get_read_chunk_size(Request) ->
    erlang:element(5, erlang:element(4, Request)).

-spec require_method(
    gleam@http@request:request(any()),
    gleam@http:method(),
    fun(() -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_method(Request, Method, Next) ->
    case erlang:element(2, Request) =:= Method of
        true ->
            Next();

        false ->
            method_not_allowed([Method])
    end.

-spec get_query(gleam@http@request:request(connection())) -> list({binary(),
    binary()}).
get_query(Request) ->
    _pipe = gleam@http@request:get_query(Request),
    gleam@result:unwrap(_pipe, []).

-spec method_override(gleam@http@request:request(NAM)) -> gleam@http@request:request(NAM).
method_override(Request) ->
    gleam@bool:guard(
        erlang:element(2, Request) /= post,
        Request,
        fun() ->
            _pipe = (gleam@result:'try'(
                gleam@http@request:get_query(Request),
                fun(Query) ->
                    gleam@result:'try'(
                        gleam@list:key_find(Query, <<"_method"/utf8>>),
                        fun(Value) ->
                            gleam@result:map(
                                gleam@http:parse_method(Value),
                                fun(Method) -> case Method of
                                        put ->
                                            gleam@http@request:set_method(
                                                Request,
                                                Method
                                            );

                                        patch ->
                                            gleam@http@request:set_method(
                                                Request,
                                                Method
                                            );

                                        delete ->
                                            gleam@http@request:set_method(
                                                Request,
                                                Method
                                            );

                                        _ ->
                                            Request
                                    end end
                            )
                        end
                    )
                end
            )),
            gleam@result:unwrap(_pipe, Request)
        end
    ).

-spec read_body_loop(
    fun((integer()) -> {ok, read()} | {error, nil}),
    integer(),
    integer(),
    bitstring()
) -> {ok, bitstring()} | {error, nil}.
read_body_loop(Reader, Read_chunk_size, Max_body_size, Accumulator) ->
    gleam@result:'try'(Reader(Read_chunk_size), fun(Chunk) -> case Chunk of
                reading_finished ->
                    {ok, Accumulator};

                {chunk, Chunk@1, Next} ->
                    Accumulator@1 = gleam@bit_array:append(Accumulator, Chunk@1),
                    case erlang:byte_size(Accumulator@1) > Max_body_size of
                        true ->
                            {error, nil};

                        false ->
                            read_body_loop(
                                Next,
                                Read_chunk_size,
                                Max_body_size,
                                Accumulator@1
                            )
                    end
            end end).

-spec read_body_to_bitstring(gleam@http@request:request(connection())) -> {ok,
        bitstring()} |
    {error, nil}.
read_body_to_bitstring(Request) ->
    Connection = erlang:element(4, Request),
    read_body_loop(
        erlang:element(2, Connection),
        erlang:element(5, Connection),
        erlang:element(3, Connection),
        <<>>
    ).

-spec require_bit_array_body(
    gleam@http@request:request(connection()),
    fun((bitstring()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_bit_array_body(Request, Next) ->
    case read_body_to_bitstring(Request) of
        {ok, Body} ->
            Next(Body);

        {error, _} ->
            entity_too_large()
    end.

-spec require_content_type(
    gleam@http@request:request(connection()),
    binary(),
    fun(() -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_content_type(Request, Expected, Next) ->
    case gleam@list:key_find(
        erlang:element(3, Request),
        <<"content-type"/utf8>>
    ) of
        {ok, Content_type} when Content_type =:= Expected ->
            Next();

        _ ->
            unsupported_media_type([Expected])
    end.

-spec bit_array_to_string(bitstring()) -> {ok, binary()} |
    {error, gleam@http@response:response(body())}.
bit_array_to_string(Bits) ->
    _pipe = gleam@bit_array:to_string(Bits),
    gleam@result:replace_error(_pipe, bad_request()).

-spec fn_with_bad_request_error(fun((NBN) -> {ok, NBO} | {error, any()})) -> fun((NBN) -> {ok,
        NBO} |
    {error, gleam@http@response:response(body())}).
fn_with_bad_request_error(F) ->
    fun(A) -> _pipe = F(A),
        gleam@result:replace_error(_pipe, bad_request()) end.

-spec multipart_content_disposition(list({binary(), binary()})) -> {ok,
        {binary(), gleam@option:option(binary())}} |
    {error, gleam@http@response:response(body())}.
multipart_content_disposition(Headers) ->
    _pipe = (gleam@result:'try'(
        gleam@list:key_find(Headers, <<"content-disposition"/utf8>>),
        fun(Header) ->
            gleam@result:'try'(
                gleam@http:parse_content_disposition(Header),
                fun(Header@1) ->
                    gleam@result:map(
                        gleam@list:key_find(
                            erlang:element(3, Header@1),
                            <<"name"/utf8>>
                        ),
                        fun(Name) ->
                            Filename = gleam@option:from_result(
                                gleam@list:key_find(
                                    erlang:element(3, Header@1),
                                    <<"filename"/utf8>>
                                )
                            ),
                            {Name, Filename}
                        end
                    )
                end
            )
        end
    )),
    gleam@result:replace_error(_pipe, bad_request()).

-spec read_chunk(buffered_reader(), integer()) -> {ok,
        {bitstring(), fun((integer()) -> {ok, read()} | {error, nil})}} |
    {error, gleam@http@response:response(body())}.
read_chunk(Reader, Chunk_size) ->
    _pipe = buffered_read(Reader, Chunk_size),
    _pipe@1 = gleam@result:replace_error(_pipe, bad_request()),
    gleam@result:'try'(_pipe@1, fun(Chunk) -> case Chunk of
                {chunk, Chunk@1, Next} ->
                    {ok, {Chunk@1, Next}};

                reading_finished ->
                    {error, bad_request()}
            end end).

-spec multipart_body(
    buffered_reader(),
    fun((bitstring()) -> {ok, gleam@http:multipart_body()} |
        {error, gleam@http@response:response(body())}),
    binary(),
    integer(),
    integer(),
    fun((NBH, bitstring()) -> {ok, NBH} |
        {error, gleam@http@response:response(body())}),
    NBH
) -> {ok, {gleam@option:option(buffered_reader()), integer(), NBH}} |
    {error, gleam@http@response:response(body())}.
multipart_body(Reader, Parse, Boundary, Chunk_size, Quota, Append, Data) ->
    gleam@result:'try'(
        read_chunk(Reader, Chunk_size),
        fun(_use0) ->
            {Chunk, Reader@1} = _use0,
            Size_read = erlang:byte_size(Chunk),
            gleam@result:'try'(Parse(Chunk), fun(Output) -> case Output of
                        {multipart_body, Parsed, Done, Remaining} ->
                            Used = (Size_read - erlang:byte_size(Remaining)) - 2,
                            Used@1 = case Done of
                                true ->
                                    (Used - 4) - erlang:byte_size(Boundary);

                                false ->
                                    Used
                            end,
                            gleam@result:'try'(
                                decrement_quota(Quota, Used@1),
                                fun(Quota@1) ->
                                    Reader@2 = {buffered_reader,
                                        Reader@1,
                                        Remaining},
                                    Reader@3 = case Done of
                                        true ->
                                            none;

                                        false ->
                                            {some, Reader@2}
                                    end,
                                    gleam@result:map(
                                        Append(Data, Parsed),
                                        fun(Value) ->
                                            {Reader@3, Quota@1, Value}
                                        end
                                    )
                                end
                            );

                        {more_required_for_body, Chunk@1, Parse@1} ->
                            Parse@2 = fn_with_bad_request_error(
                                fun(_capture) -> Parse@1(_capture) end
                            ),
                            Reader@4 = {buffered_reader, Reader@1, <<>>},
                            gleam@result:'try'(
                                Append(Data, Chunk@1),
                                fun(Data@1) ->
                                    multipart_body(
                                        Reader@4,
                                        Parse@2,
                                        Boundary,
                                        Chunk_size,
                                        Quota,
                                        Append,
                                        Data@1
                                    )
                                end
                            )
                    end end)
        end
    ).

-spec multipart_headers(
    buffered_reader(),
    fun((bitstring()) -> {ok, gleam@http:multipart_headers()} |
        {error, gleam@http@response:response(body())}),
    integer(),
    quotas()
) -> {ok, {list({binary(), binary()}), buffered_reader(), quotas()}} |
    {error, gleam@http@response:response(body())}.
multipart_headers(Reader, Parse, Chunk_size, Quotas) ->
    gleam@result:'try'(
        read_chunk(Reader, Chunk_size),
        fun(_use0) ->
            {Chunk, Reader@1} = _use0,
            gleam@result:'try'(Parse(Chunk), fun(Headers) -> case Headers of
                        {multipart_headers, Headers@1, Remaining} ->
                            Used = erlang:byte_size(Chunk) - erlang:byte_size(
                                Remaining
                            ),
                            gleam@result:map(
                                decrement_body_quota(Quotas, Used),
                                fun(Quotas@1) ->
                                    Reader@2 = {buffered_reader,
                                        Reader@1,
                                        Remaining},
                                    {Headers@1, Reader@2, Quotas@1}
                                end
                            );

                        {more_required_for_headers, Parse@1} ->
                            Parse@2 = fun(Chunk@1) -> _pipe = Parse@1(Chunk@1),
                                gleam@result:replace_error(_pipe, bad_request()) end,
                            Reader@3 = {buffered_reader, Reader@1, <<>>},
                            multipart_headers(
                                Reader@3,
                                Parse@2,
                                Chunk_size,
                                Quotas
                            )
                    end end)
        end
    ).

-spec sort_keys(list({binary(), NCF})) -> list({binary(), NCF}).
sort_keys(Pairs) ->
    gleam@list:sort(
        Pairs,
        fun(A, B) ->
            gleam@string:compare(erlang:element(1, A), erlang:element(1, B))
        end
    ).

-spec or_400(
    {ok, NCI} | {error, any()},
    fun((NCI) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
or_400(Result, Next) ->
    case Result of
        {ok, Value} ->
            Next(Value);

        {error, _} ->
            bad_request()
    end.

-spec require_string_body(
    gleam@http@request:request(connection()),
    fun((binary()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_string_body(Request, Next) ->
    case read_body_to_bitstring(Request) of
        {ok, Body} ->
            or_400(gleam@bit_array:to_string(Body), Next);

        {error, _} ->
            entity_too_large()
    end.

-spec require_json(
    gleam@http@request:request(connection()),
    fun((gleam@dynamic:dynamic_()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_json(Request, Next) ->
    require_content_type(
        Request,
        <<"application/json"/utf8>>,
        fun() ->
            require_string_body(
                Request,
                fun(Body) ->
                    or_400(
                        gleam@json:decode(
                            Body,
                            fun(Field@0) -> {ok, Field@0} end
                        ),
                        fun(Json) -> Next(Json) end
                    )
                end
            )
        end
    ).

-spec require_urlencoded_form(
    gleam@http@request:request(connection()),
    fun((form_data()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_urlencoded_form(Request, Next) ->
    require_string_body(
        Request,
        fun(Body) ->
            or_400(
                gleam@uri:parse_query(Body),
                fun(Pairs) ->
                    Pairs@1 = sort_keys(Pairs),
                    Next({form_data, Pairs@1, []})
                end
            )
        end
    ).

-spec remove_preceeding_slashes(binary()) -> binary().
remove_preceeding_slashes(String) ->
    case String of
        <<"/"/utf8, Rest/binary>> ->
            remove_preceeding_slashes(Rest);

        _ ->
            String
    end.

-spec join_path(binary(), binary()) -> binary().
join_path(A, B) ->
    B@1 = remove_preceeding_slashes(B),
    case gleam@string:ends_with(A, <<"/"/utf8>>) of
        true ->
            <<A/binary, B@1/binary>>;

        false ->
            <<<<A/binary, "/"/utf8>>/binary, B@1/binary>>
    end.

-spec serve_static(
    gleam@http@request:request(connection()),
    binary(),
    binary(),
    fun(() -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
serve_static(Req, Prefix, Directory, Handler) ->
    Path = remove_preceeding_slashes(erlang:element(8, Req)),
    Prefix@1 = remove_preceeding_slashes(Prefix),
    case {erlang:element(2, Req), gleam@string:starts_with(Path, Prefix@1)} of
        {get, true} ->
            Path@1 = begin
                _pipe = Path,
                _pipe@1 = gleam@string:drop_left(
                    _pipe,
                    gleam@string:length(Prefix@1)
                ),
                _pipe@2 = gleam@string:replace(
                    _pipe@1,
                    <<".."/utf8>>,
                    <<""/utf8>>
                ),
                join_path(Directory, _pipe@2)
            end,
            Mime_type = begin
                _pipe@3 = erlang:element(8, Req),
                _pipe@4 = gleam@string:split(_pipe@3, <<"."/utf8>>),
                _pipe@5 = gleam@list:last(_pipe@4),
                _pipe@6 = gleam@result:unwrap(_pipe@5, <<""/utf8>>),
                marceau:extension_to_mime_type(_pipe@6)
            end,
            case simplifile:verify_is_file(Path@1) of
                {ok, true} ->
                    _pipe@7 = gleam@http@response:new(200),
                    _pipe@8 = gleam@http@response:set_header(
                        _pipe@7,
                        <<"content-type"/utf8>>,
                        Mime_type
                    ),
                    gleam@http@response:set_body(_pipe@8, {file, Path@1});

                _ ->
                    Handler()
            end;

        {_, _} ->
            Handler()
    end.

-spec handle_head(
    gleam@http@request:request(connection()),
    fun((gleam@http@request:request(connection())) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
handle_head(Req, Handler) ->
    case erlang:element(2, Req) of
        head ->
            _pipe = Req,
            _pipe@1 = gleam@http@request:set_method(_pipe, get),
            _pipe@2 = gleam@http@request:prepend_header(
                _pipe@1,
                <<"x-original-method"/utf8>>,
                <<"HEAD"/utf8>>
            ),
            _pipe@3 = Handler(_pipe@2),
            gleam@http@response:set_body(_pipe@3, empty);

        _ ->
            Handler(Req)
    end.

-spec delete_temporary_files(gleam@http@request:request(connection())) -> {ok,
        nil} |
    {error, simplifile:file_error()}.
delete_temporary_files(Request) ->
    case simplifile:delete(erlang:element(7, erlang:element(4, Request))) of
        {error, enoent} ->
            {ok, nil};

        Other ->
            Other
    end.

-spec configure_logger() -> nil.
configure_logger() ->
    logging_ffi:configure().

-spec log_emergency(binary()) -> nil.
log_emergency(Message) ->
    logging:log(emergency, Message).

-spec log_alert(binary()) -> nil.
log_alert(Message) ->
    logging:log(alert, Message).

-spec log_critical(binary()) -> nil.
log_critical(Message) ->
    logging:log(critical, Message).

-spec log_error(binary()) -> nil.
log_error(Message) ->
    logging:log(error, Message).

-spec mist_send_file(binary()) -> mist:response_data().
mist_send_file(Path) ->
    case mist:send_file(Path, 0, none) of
        {ok, Body} ->
            Body;

        {error, Error} ->
            log_error(gleam@string:inspect(Error)),
            {bytes, gleam@bytes_builder:new()}
    end.

-spec mist_response(gleam@http@response:response(body())) -> gleam@http@response:response(mist:response_data()).
mist_response(Response) ->
    Body = case erlang:element(4, Response) of
        empty ->
            {bytes, gleam@bytes_builder:new()};

        {text, Text} ->
            {bytes, gleam_stdlib:wrap_list(Text)};

        {file, Path} ->
            mist_send_file(Path)
    end,
    _pipe = Response,
    gleam@http@response:set_body(_pipe, Body).

-spec or_500({ok, NAZ} | {error, any()}) -> {ok, NAZ} |
    {error, gleam@http@response:response(body())}.
or_500(Result) ->
    case Result of
        {ok, Value} ->
            {ok, Value};

        {error, Error} ->
            log_error(gleam@string:inspect(Error)),
            {error, internal_server_error()}
    end.

-spec multipart_file_append(binary(), bitstring()) -> {ok, binary()} |
    {error, gleam@http@response:response(body())}.
multipart_file_append(Path, Chunk) ->
    _pipe = simplifile:append_bits(Path, Chunk),
    _pipe@1 = or_500(_pipe),
    gleam@result:replace(_pipe@1, Path).

-spec rescue_crashes(fun(() -> gleam@http@response:response(body()))) -> gleam@http@response:response(body()).
rescue_crashes(Handler) ->
    case exception_ffi:rescue(Handler) of
        {ok, Response} ->
            Response;

        {error, Error} ->
            {Kind, Detail@3} = case Error of
                {errored, Detail} ->
                    {errored, Detail};

                {thrown, Detail@1} ->
                    {thrown, Detail@1};

                {exited, Detail@2} ->
                    {exited, Detail@2}
            end,
            case (gleam@dynamic:dict(
                fun gleam_erlang_ffi:atom_from_dynamic/1,
                fun(Field@0) -> {ok, Field@0} end
            ))(Detail@3) of
                {ok, Details} ->
                    C = erlang:binary_to_atom(<<"class"/utf8>>),
                    logger:error(
                        gleam@dict:insert(Details, C, gleam@dynamic:from(Kind))
                    ),
                    nil;

                {error, _} ->
                    log_error(gleam@string:inspect(Error))
            end,
            internal_server_error()
    end.

-spec log_warning(binary()) -> nil.
log_warning(Message) ->
    logging:log(warning, Message).

-spec log_notice(binary()) -> nil.
log_notice(Message) ->
    logging:log(notice, Message).

-spec log_info(binary()) -> nil.
log_info(Message) ->
    logging:log(info, Message).

-spec log_request(
    gleam@http@request:request(connection()),
    fun(() -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
log_request(Req, Handler) ->
    Response = Handler(),
    _pipe = [gleam@int:to_string(erlang:element(2, Response)),
        <<" "/utf8>>,
        gleam@string:uppercase(
            gleam@http:method_to_string(erlang:element(2, Req))
        ),
        <<" "/utf8>>,
        erlang:element(8, Req)],
    _pipe@1 = gleam@string:concat(_pipe),
    log_info(_pipe@1),
    Response.

-spec log_debug(binary()) -> nil.
log_debug(Message) ->
    logging:log(debug, Message).

-spec random_string(integer()) -> binary().
random_string(Length) ->
    _pipe = crypto:strong_rand_bytes(Length),
    _pipe@1 = gleam@bit_array:base64_url_encode(_pipe, false),
    gleam@string:slice(_pipe@1, 0, Length).

-spec sign_message(
    gleam@http@request:request(connection()),
    bitstring(),
    gleam@crypto:hash_algorithm()
) -> binary().
sign_message(Request, Message, Algorithm) ->
    gleam@crypto:sign_message(
        Message,
        <<(erlang:element(6, erlang:element(4, Request)))/binary>>,
        Algorithm
    ).

-spec verify_signed_message(gleam@http@request:request(connection()), binary()) -> {ok,
        bitstring()} |
    {error, nil}.
verify_signed_message(Request, Message) ->
    gleam@crypto:verify_signed_message(
        Message,
        <<(erlang:element(6, erlang:element(4, Request)))/binary>>
    ).

-spec random_slug() -> binary().
random_slug() ->
    random_string(16).

-spec make_connection(fun((integer()) -> {ok, read()} | {error, nil}), binary()) -> connection().
make_connection(Body_reader, Secret_key_base) ->
    Prefix = <<"/tmp/gleam-wisp/"/utf8>>,
    Temporary_directory = join_path(Prefix, random_slug()),
    {connection,
        Body_reader,
        8000000,
        32000000,
        1000000,
        Secret_key_base,
        Temporary_directory}.

-spec mist_handler(
    fun((gleam@http@request:request(connection())) -> gleam@http@response:response(body())),
    binary()
) -> fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(mist:response_data())).
mist_handler(Handler, Secret_key_base) ->
    fun(Request) ->
        Connection = make_connection(mist_body_reader(Request), Secret_key_base),
        Request@1 = gleam@http@request:set_body(Request, Connection),
        exception_ffi:defer(
            fun() -> _assert_subject = delete_temporary_files(Request@1),
                {ok, _} = case _assert_subject of
                    {ok, _} -> _assert_subject;
                    _assert_fail ->
                        erlang:error(#{gleam_error => let_assert,
                                    message => <<"Assertion pattern match failed"/utf8>>,
                                    value => _assert_fail,
                                    module => <<"wisp"/utf8>>,
                                    function => <<"mist_handler"/utf8>>,
                                    line => 59})
                end end,
            fun() ->
                Response = begin
                    _pipe = Request@1,
                    _pipe@1 = Handler(_pipe),
                    mist_response(_pipe@1)
                end,
                Response
            end
        )
    end.

-spec new_temporary_file(gleam@http@request:request(connection())) -> {ok,
        binary()} |
    {error, simplifile:file_error()}.
new_temporary_file(Request) ->
    Directory = erlang:element(7, erlang:element(4, Request)),
    gleam@result:'try'(
        simplifile:create_directory_all(Directory),
        fun(_) ->
            Path = join_path(Directory, random_slug()),
            gleam@result:map(simplifile:create_file(Path), fun(_) -> Path end)
        end
    ).

-spec read_multipart(
    gleam@http@request:request(connection()),
    buffered_reader(),
    binary(),
    quotas(),
    form_data()
) -> {ok, form_data()} | {error, gleam@http@response:response(body())}.
read_multipart(Request, Reader, Boundary, Quotas, Data) ->
    Read_size = erlang:element(5, erlang:element(4, Request)),
    Header_parser = fn_with_bad_request_error(
        fun(_capture) ->
            gleam@http:parse_multipart_headers(_capture, Boundary)
        end
    ),
    Result = multipart_headers(Reader, Header_parser, Read_size, Quotas),
    gleam@result:'try'(
        Result,
        fun(_use0) ->
            {Headers, Reader@1, Quotas@1} = _use0,
            gleam@result:'try'(
                multipart_content_disposition(Headers),
                fun(_use0@1) ->
                    {Name, Filename} = _use0@1,
                    Parse = fn_with_bad_request_error(
                        fun(_capture@1) ->
                            gleam@http:parse_multipart_body(
                                _capture@1,
                                Boundary
                            )
                        end
                    ),
                    gleam@result:'try'(case Filename of
                            {some, File_name} ->
                                gleam@result:'try'(
                                    or_500(new_temporary_file(Request)),
                                    fun(Path) ->
                                        Append = fun multipart_file_append/2,
                                        Q = erlang:element(3, Quotas@1),
                                        Result@1 = multipart_body(
                                            Reader@1,
                                            Parse,
                                            Boundary,
                                            Read_size,
                                            Q,
                                            Append,
                                            Path
                                        ),
                                        gleam@result:map(
                                            Result@1,
                                            fun(_use0@2) ->
                                                {Reader@2, Quota, _} = _use0@2,
                                                Quotas@2 = erlang:setelement(
                                                    3,
                                                    Quotas@1,
                                                    Quota
                                                ),
                                                File = {uploaded_file,
                                                    File_name,
                                                    Path},
                                                Data@1 = erlang:setelement(
                                                    3,
                                                    Data,
                                                    [{Name, File} |
                                                        erlang:element(3, Data)]
                                                ),
                                                {Data@1, Reader@2, Quotas@2}
                                            end
                                        )
                                    end
                                );

                            none ->
                                Append@1 = fun(Data@2, Chunk) ->
                                    {ok, gleam@bit_array:append(Data@2, Chunk)}
                                end,
                                Q@1 = erlang:element(2, Quotas@1),
                                Result@2 = multipart_body(
                                    Reader@1,
                                    Parse,
                                    Boundary,
                                    Read_size,
                                    Q@1,
                                    Append@1,
                                    <<>>
                                ),
                                gleam@result:'try'(
                                    Result@2,
                                    fun(_use0@3) ->
                                        {Reader@3, Quota@1, Value} = _use0@3,
                                        Quotas@3 = erlang:setelement(
                                            2,
                                            Quotas@1,
                                            Quota@1
                                        ),
                                        gleam@result:map(
                                            bit_array_to_string(Value),
                                            fun(Value@1) ->
                                                Data@3 = erlang:setelement(
                                                    2,
                                                    Data,
                                                    [{Name, Value@1} |
                                                        erlang:element(2, Data)]
                                                ),
                                                {Data@3, Reader@3, Quotas@3}
                                            end
                                        )
                                    end
                                )
                        end, fun(_use0@4) ->
                            {Data@4, Reader@4, Quotas@4} = _use0@4,
                            case Reader@4 of
                                {some, Reader@5} ->
                                    read_multipart(
                                        Request,
                                        Reader@5,
                                        Boundary,
                                        Quotas@4,
                                        Data@4
                                    );

                                none ->
                                    {ok,
                                        {form_data,
                                            sort_keys(erlang:element(2, Data@4)),
                                            sort_keys(erlang:element(3, Data@4))}}
                            end
                        end)
                end
            )
        end
    ).

-spec require_multipart_form(
    gleam@http@request:request(connection()),
    binary(),
    fun((form_data()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_multipart_form(Request, Boundary, Next) ->
    Quotas = {quotas,
        erlang:element(3, erlang:element(4, Request)),
        erlang:element(4, erlang:element(4, Request))},
    Reader = {buffered_reader,
        erlang:element(2, erlang:element(4, Request)),
        <<>>},
    Result = read_multipart(
        Request,
        Reader,
        Boundary,
        Quotas,
        {form_data, [], []}
    ),
    case Result of
        {ok, Form_data} ->
            Next(Form_data);

        {error, Response} ->
            Response
    end.

-spec require_form(
    gleam@http@request:request(connection()),
    fun((form_data()) -> gleam@http@response:response(body()))
) -> gleam@http@response:response(body()).
require_form(Request, Next) ->
    case gleam@list:key_find(
        erlang:element(3, Request),
        <<"content-type"/utf8>>
    ) of
        {ok, <<"application/x-www-form-urlencoded"/utf8>>} ->
            require_urlencoded_form(Request, Next);

        {ok, <<"application/x-www-form-urlencoded;"/utf8, _/binary>>} ->
            require_urlencoded_form(Request, Next);

        {ok, <<"multipart/form-data; boundary="/utf8, Boundary/binary>>} ->
            require_multipart_form(Request, Boundary, Next);

        {ok, <<"multipart/form-data"/utf8>>} ->
            bad_request();

        _ ->
            unsupported_media_type(
                [<<"application/x-www-form-urlencoded"/utf8>>,
                    <<"multipart/form-data"/utf8>>]
            )
    end.

-spec set_cookie(
    gleam@http@response:response(body()),
    gleam@http@request:request(connection()),
    binary(),
    binary(),
    security(),
    integer()
) -> gleam@http@response:response(body()).
set_cookie(Response, Request, Name, Value, Security, Max_age) ->
    Attributes = erlang:setelement(
        2,
        gleam@http@cookie:defaults(https),
        {some, Max_age}
    ),
    Value@1 = case Security of
        plain_text ->
            gleam@bit_array:base64_encode(<<Value/binary>>, false);

        signed ->
            sign_message(Request, <<Value/binary>>, sha512)
    end,
    _pipe = Response,
    gleam@http@response:set_cookie(_pipe, Name, Value@1, Attributes).

-spec get_cookie(gleam@http@request:request(connection()), binary(), security()) -> {ok,
        binary()} |
    {error, nil}.
get_cookie(Request, Name, Security) ->
    gleam@result:'try'(
        begin
            _pipe = Request,
            _pipe@1 = gleam@http@request:get_cookies(_pipe),
            gleam@list:key_find(_pipe@1, Name)
        end,
        fun(Value) -> gleam@result:'try'(case Security of
                    plain_text ->
                        gleam@bit_array:base64_decode(Value);

                    signed ->
                        verify_signed_message(Request, Value)
                end, fun(Value@1) -> gleam@bit_array:to_string(Value@1) end) end
    ).

-spec create_canned_connection(bitstring(), binary()) -> connection().
create_canned_connection(Body, Secret_key_base) ->
    make_connection(
        fun(_) -> {ok, {chunk, Body, fun(_) -> {ok, reading_finished} end}} end,
        Secret_key_base
    ).
