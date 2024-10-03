module pq

using Base.Libc.Libdl

const libpq::String = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq_rs.dll"))

# Base.write(io::IO, s::Cstring) = write(io, unsafe_string(s))
# Base.print(io::IO, s::Cstring) = (write(io, unsafe_string(s)); nothing)
# Base.show(io::IO, s::Cstring) = show(io, unsafe_string(s))

# Base.write(io::IO, s::Ptr{Cchar}) = write(io, unsafe_string(s))
# Base.print(io::IO, s::Ptr{Cchar}) = (write(io, unsafe_string(s)); nothing)
# Base.show(io::IO, s::Ptr{Cchar}) = show(io, unsafe_string(s))

mutable struct CsvString
    ptr::Ptr{Cchar}
    len::UInt32
    error::Ptr{Cchar}
end

Base.print(io::IO, s::CsvString) = (write(io, begin
    if s.ptr != C_NULL
        unsafe_string(s.ptr, s.len)
    elseif s.error != C_NULL
        unsafe_string(s.error)
    else
        ""
    end
end);
nothing)

function conn(url)::Ptr{Cvoid}
    ccall((:conn, libpq), Ptr{Cvoid}, (Cstring,), url)
end

function execute(c, sql)::Cint
    ccall((:execute, libpq), Cint, (Ptr{Cvoid}, Cstring), c, sql)
end

function copyout_csv(c, select_sql; delimiter="\t")::CsvString
    copyout_sql = "COPY ($select_sql) TO STDOUT (FORMAT CSV, HEADER, DELIMITER '$delimiter', ENCODING 'utf-8');"
    ccall((:copyout, libpq), CsvString, (Ptr{Cvoid}, Cstring), c, copyout_sql)
end

function free_csvstring(x)
    ccall((:free_csvstring, libpq), Cvoid, (CsvString,), x)
end

function disconnect(c)::Cvoid
    ccall((:disconnect, libpq), Cvoid, (Ptr{Cvoid},), c)
end

export conn, execute, copyout_csv, free_csvstring, disconnect
end
