const libpq_path = normpath(joinpath(dirname(@__FILE__), "..", "target", "release", "libpq.$(Sys.iswindows() ? "dll" : "so")"))

Base.write(io::IO, s::Cstring) = write(io, unsafe_string(s))
Base.print(io::IO, s::Cstring) = (write(io, unsafe_string(s)); nothing)
Base.show(io::IO, s::Cstring) = show(io, unsafe_string(s))
