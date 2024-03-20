-record(loop_state, {
    client_ip :: {ok, {{integer(), integer(), integer(), integer()}, integer()}} |
        {error, nil},
    socket :: glisten@socket:socket(),
    sender :: gleam@erlang@process:subject(glisten@handler:message(any())),
    transport :: glisten@socket@transport:transport(),
    data :: any()
}).
