-module(mist@internal@file).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([sendfile/5, stat/1]).
-export_type([file_descriptor/0, file_error/0, file/0]).

-type file_descriptor() :: any().

-type file_error() :: is_dir | no_access | no_entry | unknown_file_error.

-type file() :: {file, file_descriptor(), integer()}.

-spec sendfile(
    file_descriptor(),
    glisten@socket:socket(),
    integer(),
    integer(),
    list(any())
) -> {ok, integer()} | {error, gleam@erlang@atom:atom_()}.
sendfile(File_descriptor, Socket, Offset, Bytes, Options) ->
    file:sendfile(File_descriptor, Socket, Offset, Bytes, Options).

-spec stat(bitstring()) -> {ok, file()} | {error, file_error()}.
stat(Filename) ->
    _pipe = Filename,
    _pipe@1 = mist_ffi:file_open(_pipe),
    gleam@result:map(
        _pipe@1,
        fun(Fd) ->
            File_size = filelib:file_size(Filename),
            {file, Fd, File_size}
        end
    ).
