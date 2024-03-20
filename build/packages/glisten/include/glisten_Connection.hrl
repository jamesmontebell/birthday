-record(connection, {
    client_ip :: {ok, {{integer(), integer(), integer(), integer()}, integer()}} |
        {error, nil},
    socket :: glisten@socket:socket(),
    transport :: glisten@socket@transport:transport(),
    subject :: gleam@erlang@process:subject(glisten@handler:message(any()))
}).
