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
    else
        getfield(df, sym)
    end
end