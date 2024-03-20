-module(glisten@socket@transport).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([socket_info/1, tcp/0, ssl/0]).
-export_type([transport/0]).

-type transport() :: {ssl,
        fun((glisten@socket:listen_socket()) -> {ok, glisten@socket:socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:listen_socket(), integer()) -> {ok,
                glisten@socket:socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> {ok, nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), gleam@erlang@process:pid_()) -> {ok, nil} |
            {error, gleam@erlang@atom:atom_()}),
        fun((glisten@socket:socket()) -> {ok, glisten@socket:socket()} |
            {error, nil}),
        fun((integer(), list(glisten@socket@options:tcp_option())) -> {ok,
                glisten@socket:listen_socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> {ok, binary()} | {error, binary()}),
        fun((glisten@socket:socket()) -> {ok,
                {{integer(), integer(), integer(), integer()}, integer()}} |
            {error, nil}),
        fun((glisten@socket:socket(), integer()) -> {ok, bitstring()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), integer(), integer()) -> {ok, bitstring()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), gleam@bytes_builder:bytes_builder()) -> {ok,
                nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), list(glisten@socket@options:tcp_option())) -> {ok,
                nil} |
            {error, nil}),
        fun((glisten@socket:socket()) -> {ok, nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> gleam@dict:dict(gleam@erlang@atom:atom_(), gleam@dynamic:dynamic_()))} |
    {tcp,
        fun((glisten@socket:listen_socket()) -> {ok, glisten@socket:socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:listen_socket(), integer()) -> {ok,
                glisten@socket:socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> {ok, nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), gleam@erlang@process:pid_()) -> {ok, nil} |
            {error, gleam@erlang@atom:atom_()}),
        fun((glisten@socket:socket()) -> {ok, glisten@socket:socket()} |
            {error, nil}),
        fun((integer(), list(glisten@socket@options:tcp_option())) -> {ok,
                glisten@socket:listen_socket()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> {ok, binary()} | {error, binary()}),
        fun((glisten@socket:socket()) -> {ok,
                {{integer(), integer(), integer(), integer()}, integer()}} |
            {error, nil}),
        fun((glisten@socket:socket(), integer()) -> {ok, bitstring()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), integer(), integer()) -> {ok, bitstring()} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), gleam@bytes_builder:bytes_builder()) -> {ok,
                nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket(), list(glisten@socket@options:tcp_option())) -> {ok,
                nil} |
            {error, nil}),
        fun((glisten@socket:socket()) -> {ok, nil} |
            {error, glisten@socket:socket_reason()}),
        fun((glisten@socket:socket()) -> gleam@dict:dict(gleam@erlang@atom:atom_(), gleam@dynamic:dynamic_()))}.

-spec socket_info(glisten@socket:socket()) -> gleam@dict:dict(any(), any()).
socket_info(Socket) ->
    socket:info(Socket).

-spec tcp() -> transport().
tcp() ->
    {tcp,
        fun gen_tcp:accept/1,
        fun gen_tcp:accept/2,
        fun glisten_tcp_ffi:close/1,
        fun glisten_tcp_ffi:controlling_process/2,
        fun glisten@tcp:handshake/1,
        fun glisten@tcp:listen/2,
        fun(_) -> {error, <<"Can't negotiate protocol on tcp"/utf8>>} end,
        fun inet:peername/1,
        fun gen_tcp:recv/2,
        fun gen_tcp:recv/3,
        fun glisten_tcp_ffi:send/2,
        fun glisten@tcp:set_opts/2,
        fun glisten@tcp:shutdown/1,
        fun socket:info/1}.

-spec ssl() -> transport().
ssl() ->
    {ssl,
        fun ssl:transport_accept/1,
        fun ssl:transport_accept/2,
        fun glisten_ssl_ffi:close/1,
        fun glisten_ssl_ffi:controlling_process/2,
        fun ssl:handshake/1,
        fun glisten@ssl:listen/2,
        fun glisten_ssl_ffi:negotiated_protocol/1,
        fun ssl:peername/1,
        fun ssl:recv/2,
        fun ssl:recv/3,
        fun glisten_ssl_ffi:send/2,
        fun glisten@ssl:set_opts/2,
        fun glisten@ssl:shutdown/1,
        fun socket:info/1}.
