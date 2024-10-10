module libpq

using CEnum

const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))

Base.write(io::IO, s::Cstring) = write(io, unsafe_string(s))
Base.print(io::IO, s::Cstring) = (write(io, unsafe_string(s)); nothing)
Base.show(io::IO, s::Cstring) = show(io, unsafe_string(s))


@cenum DTypes::UInt32 begin
    I8 = 0
    I32 = 1
    I64 = 2
    F32 = 3
    F64 = 4
    Str = 5
end

mutable struct DFrame
    width::UInt32
    height::UInt32
    fields::Ptr{Ptr{UInt8}}
    types::Ptr{DTypes}
    values::Ptr{Ptr{Cvoid}}
    err_code::UInt32
    err_msg::Ptr{Int8}
end

mutable struct Copyout
    body::Ptr{Int8}
    len::UInt32
    err::UInt32
end

function pq_conn(url)
    ccall((:pq_conn, libpq_path), Ptr{Cvoid}, (Ptr{Int8},), url)
end

"""
    pq_execute(c, sql)

Executes a statement, returning the number of rows modified.

Returns -1 if client is null Returns -2 if execute failed Returns -3 if invalid sql
"""
function pq_execute(c, sql)
    ccall((:pq_execute, libpq_path), Int64, (Ptr{Cvoid}, Ptr{Int8}), c, sql)
end

"""
    pq_query_native(c, sql)

query a sql and return a dataframe
"""
function pq_query_native(c, sql)
    ccall((:pq_query_native, libpq_path), DFrame, (Ptr{Cvoid}, Ptr{Int8}), c, sql)
end

"""
    pq_free_dframe(df)

free data frame
"""
function pq_free_dframe(df)
    ccall((:pq_free_dframe, libpq_path), Cvoid, (DFrame,), df)
end

"""
    pq_copyout_native(c, sql, delim, header)

copy out query result to csv string
"""
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

function pq_copyout(c, sql; delim='\t', header=true)
    out = pq_copyout_native(c, sql, delim, header ? 1 : 0)
    Base.finalizer(out) do x
        @async begin
            pq_free_copyout(x)
        end
    end
    out
end

Base.getproperty(out::Copyout, sym::Symbol) = begin
    if sym === :body
        unsafe_string(getfield(out, sym), out.len)
    else
        getfield(out, sym)
    end
end

function pq_query(c, sql)
    df = pq_query_native(c, sql)
    Base.finalizer(df) do x
        @async begin
            pq_free_dframe(x)
        end
    end
    df
end

Base.getproperty(df::DFrame, sym::Symbol) = begin
    if sym === :fields
        unsafe_wrap(Array{Cstring}, Ptr{Cstring}(getfield(df, sym)), df.width)
    elseif sym === :types
        unsafe_wrap(Array{DTypes}, Ptr{DTypes}(getfield(df, sym)), df.width)
    elseif sym === :values
        types = unsafe_wrap(Array{DTypes}, Ptr{DTypes}(getfield(df, :types)), df.width)
        ptrs = unsafe_wrap(Array{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}}(getfield(df, sym)), df.width)
        values = Vector{Vector{Any}}(undef, df.width)
        for i in 1:df.width
            if types[i] == I8
                values[i] = unsafe_wrap(Array, Ptr{Int8}(ptrs[i]), df.height)
            elseif types[i] == I32
                values[i] = unsafe_wrap(Array, Ptr{Int32}(ptrs[i]), df.height)
            elseif types[i] == I64
                values[i] = unsafe_wrap(Array, Ptr{Int64}(ptrs[i]), df.height)
            elseif types[i] == F32
                values[i] = unsafe_wrap(Array, Ptr{Float32}(ptrs[i]), df.height)
            elseif types[i] == F64
                values[i] = unsafe_wrap(Array, Ptr{Float64}(ptrs[i]), df.height)
            else
                values[i] = unsafe_wrap(Array, Ptr{Cstring}(ptrs[i]), df.height)
            end
        end
        values
    else
        getfield(df, sym)
    end
end

# exports
const PREFIXES = ["pq_"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
