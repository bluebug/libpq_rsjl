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