-record(pool, {
    listener_socket :: glisten@socket:listen_socket(),
    handler :: fun((glisten@handler:loop_message(any()), any(), glisten@handler:connection(any())) -> gleam@otp@actor:next(glisten@handler:loop_message(any()), any())),
    pool_count :: integer(),
    on_init :: fun(() -> {any(),
        gleam@option:option(gleam@erlang@process:selector(any()))}),
    on_close :: gleam@option:option(fun((any()) -> nil)),
    transport :: glisten@socket@transport:transport()
}).
