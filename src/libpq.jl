module libpq

using CEnum

const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))

mutable struct Copyout
    body::Ptr{Int8}
    len::UInt32
    err::UInt32
end

function pq_conn(url)
    ccall((:pq_conn, libpq_path), Ptr{Cvoid}, (Ptr{Int8},), url)
end

function pq_execute(c, sql)
    ccall((:pq_execute, libpq_path), Int64, (Ptr{Cvoid}, Ptr{Int8}), c, sql)
end

function pq_copyout_native(c, sql, delim, header)
    ccall((:pq_copyout_native, libpq_path), Copyout, (Ptr{Cvoid}, Ptr{Int8}, Cchar, UInt8), c, sql, delim, header)
end

function pq_show_copyout(s)
    ccall((:pq_show_copyout, libpq_path), Cvoid, (Copyout,), s)
end

function pq_free_copyout(s)
    ccall((:pq_free_copyout, libpq_path), Cvoid, (Copyout,), s)
end

function pq_disconn(c)
    ccall((:pq_disconn, libpq_path), Cvoid, (Ptr{Cvoid},), c)
end

Base.write(io::IO, s::Copyout) = write(io, unsafe_string(s.body, s.len))
Base.print(io::IO, s::Copyout) = (write(io, unsafe_string(s.body, s.len)); nothing)
Base.show(io::IO, s::Copyout) = show(io, unsafe_string(s.body, s.len))

function pq_copyout(c, sql; delim='\t', header=true)
    csv = pq_copyout_native(c, sql, delim, header ? 1 : 0)
    Base.finalizer(csv) do s
        @async begin
            pq_free_copyout(s)
        end
    end
    csv
end

# exports
const PREFIXES = ["pq_"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
