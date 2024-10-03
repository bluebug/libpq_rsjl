module pq

using Base.Libc.Libdl

const libpq::String = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq_rs.dll"))

# Base.write(io::IO, s::Cstring) = write(io, unsafe_string(s))
# Base.print(io::IO, s::Cstring) = (write(io, unsafe_string(s)); nothing)
# Base.show(io::IO, s::Cstring) = show(io, unsafe_string(s))

# Base.write(io::IO, s::Ptr{Cchar}) = write(io, unsafe_string(s))
# Base.print(io::IO, s::Ptr{Cchar}) = (write(io, unsafe_string(s)); nothing)
# Base.show(io::IO, s::Ptr{Cchar}) = show(io, unsafe_string(s))

function conn(url)::Ptr{Cvoid}
    ccall((:conn, libpq), Ptr{Cvoid}, (Cstring,), url)
end

function execute(c, sql)::Cint
    ccall((:execute, libpq), Cint, (Ptr{Cvoid}, Cstring), c, sql)
end

function copyout_csv(c, select_sql; delimiter="\t")::String
    copyout_sql = "COPY ($select_sql) TO STDOUT (FORMAT CSV, HEADER, DELIMITER '$delimiter', ENCODING 'utf-8');"
    s = ccall((:copyout, libpq), Cstring, (Ptr{Cvoid}, Cstring), c, copyout_sql)
    csv = unsafe_string(s)
    free_str(s)

    csv
end

function disconnect(c)::Cvoid
    ccall((:disconnect, libpq), Cvoid, (Ptr{Cvoid},), c)
end

function free_str(s)
    ccall((:free_str, libpq), Cvoid, (Cstring,), s)

    nothing
end

export conn, execute, copyout_csv, disconnect
end
