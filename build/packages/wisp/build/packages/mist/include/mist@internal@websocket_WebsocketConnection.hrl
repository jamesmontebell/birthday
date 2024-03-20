-record(websocket_connection, {
    socket :: glisten@socket:socket(),
    transport :: glisten@socket@transport:transport()
}).
