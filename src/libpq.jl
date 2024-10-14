module libpq

using CEnum

using StringViews

function CStringLength(cs)
    ptr = Ptr{UInt8}(cs)
    if ptr == C_NULL
        0
    else
        ccall(:strlen, Cint, (Ptr{UInt8},), ptr)
    end
end

function CStringView(cs)
    ptr = Ptr{UInt8}(cs)
    if ptr == C_NULL
        StringView("")
    else
        StringView(unsafe_wrap(Array, ptr, length(cs)))
    end
end
Base.length(cs::Cstring) = CStringLength(cs)
Base.write(io::IO, cs::Cstring) = write(io, CStringView(cs))
Base.print(io::IO, cs::Cstring) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Cstring) = show(io, CStringView(cs))

Base.length(cs::Ptr{UInt8}) = CStringLength(cs)
Base.write(io::IO, cs::Ptr{UInt8}) = write(io, CStringView(cs))
Base.print(io::IO, cs::Ptr{UInt8}) = (write(io, CStringView(cs)); nothing)
Base.show(io::IO, cs::Ptr{UInt8}) = show(io, CStringView(cs))

export CStringView

const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))


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
    err_msg::Ptr{UInt8}
end

mutable struct Copyout
    body::Ptr{UInt8}
    len::UInt32
    err::UInt32
end

"""
    pq_conn(url)

### Prototype
```c
const void *pq_conn(const int8_t *url);
```
"""
function pq_conn(url)
    ccall((:pq_conn, libpq_path), Ptr{Cvoid}, (Ptr{Int8},), url)
end

"""
    pq_execute(c, sql)

Executes a statement, returning the number of rows modified.

Returns -1 if client is null Returns -2 if execute failed Returns -3 if invalid sql

### Prototype
```c
int64_t pq_execute(const void *c, const int8_t *sql);
```
"""
function pq_execute(c, sql)
    ccall((:pq_execute, libpq_path), Int64, (Ptr{Cvoid}, Ptr{Int8}), c, sql)
end

"""
    pq_query_native(c, sql)

query a sql and return a dataframe

### Prototype
```c
struct DFrame pq_query_native(const void *c, const int8_t *sql);
```
"""
function pq_query_native(c, sql)
    ccall((:pq_query_native, libpq_path), DFrame, (Ptr{Cvoid}, Ptr{Int8}), c, sql)
end

"""
    pq_free_dframe(df)

free data frame

### Prototype
```c
void pq_free_dframe(struct DFrame df);
```
"""
function pq_free_dframe(df)
    ccall((:pq_free_dframe, libpq_path), Cvoid, (DFrame,), df)
end

"""
    pq_copyout_native(c, sql, delim, header)

copy out query result to csv string

### Prototype
```c
struct Copyout pq_copyout_native(const void *c, const int8_t *sql, char delim, uint8_t header);
```
"""
function pq_copyout_native(c, sql, delim, header)
    ccall((:pq_copyout_native, libpq_path), Copyout, (Ptr{Cvoid}, Ptr{Int8}, Cchar, UInt8), c, sql, delim, header)
end

"""
    pq_show_copyout(s)

### Prototype
```c
void pq_show_copyout(struct Copyout s);
```
"""
function pq_show_copyout(s)
    ccall((:pq_show_copyout, libpq_path), Cvoid, (Copyout,), s)
end

"""
    pq_free_copyout(s)

### Prototype
```c
void pq_free_copyout(struct Copyout s);
```
"""
function pq_free_copyout(s)
    ccall((:pq_free_copyout, libpq_path), Cvoid, (Copyout,), s)
end

"""
    pq_disconn(c)

### Prototype
```c
void pq_disconn(void *c);
```
"""
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
    if sym === :buf
        IOBuffer(unsafe_wrap(Array, out.body, out.len))
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
    elseif sym === :columns
        columns = Dict{Union{String,Cstring},Vector}()
        fields = unsafe_wrap(Array{Cstring}, Ptr{Cstring}(getfield(df, :fields)), df.width)
        types = unsafe_wrap(Array{DTypes}, Ptr{DTypes}(getfield(df, :types)), df.width)
        ptrs = unsafe_wrap(Array{Ptr{Cvoid}}, Ptr{Ptr{Cvoid}}(getfield(df, :values)), df.width)
        for i in 1:df.width
            column_name = unsafe_string(fields[i])
            columns[column_name] = columns[fields[i]] = begin
                if types[i] == I8
                    unsafe_wrap(Array, Ptr{Int8}(ptrs[i]), df.height)
                elseif types[i] == I32
                    unsafe_wrap(Array, Ptr{Int32}(ptrs[i]), df.height)
                elseif types[i] == I64
                    unsafe_wrap(Array, Ptr{Int64}(ptrs[i]), df.height)
                elseif types[i] == F32
                    unsafe_wrap(Array, Ptr{Float32}(ptrs[i]), df.height)
                elseif types[i] == F64
                    unsafe_wrap(Array, Ptr{Float64}(ptrs[i]), df.height)
                else
                    unsafe_wrap(Array, Ptr{Cstring}(ptrs[i]), df.height)
                end
            end
        end
        columns
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
